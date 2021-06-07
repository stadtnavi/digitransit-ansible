#!/usr/bin/env python3
"""
Add missing PT information to a Nominatim database.

The script expects a CSV file with the following fields:

 * Landkreis  - address county
 * Gemeinde   - address city
 * Ortsteil   - address district
 * Haltestelle - name
 * Haltestelle_lang - alt_name
 * globaleID - IFOPT ID
 * lat, lon  - Geographic location
 * osm_id    - OSM id of the form <nwr><id>

For each field, the script first tries to find the corresponding OSM object
in the Nominatim database and add the ifopt, if necessary. If no object
is found or there was no matching OSM object available in the first place,
then an artifical object is added using the name, address and position
information from the CSV.

To use the script in on an existing Photon export with updates:

Initialisation:
 * Run script against the Nominatim database using '-i' parameter to force
   an invalidation of all objects.
 * Run photon update script.

On Updates:
 * Run OSM update on Nominatim database.
 * Run script against the Nominatim database without '-i' parameter.
 * Run photon update script.
"""

from argparse import ArgumentParser, RawDescriptionHelpFormatter
from collections import Counter
import csv
import gzip
import logging
import sys

import psycopg2
import psycopg2.extras

LOG = logging.getLogger()

def connect(args):
    """ Create a connection from the given command line arguments.
    """
    conn = psycopg2.connect(dbname=args.database, user=args.username,
                            host=args.host, port=args.port, password=args.password)

    psycopg2.extras.register_hstore(conn)

    return conn


def get_parser():
    parser = ArgumentParser(description=__doc__,
                            formatter_class=RawDescriptionHelpFormatter)
    parser.add_argument('-q', '--quiet', action='store_const', const=0,
                        dest='verbose', default=2,
                        help='Print only error messages')
    parser.add_argument('-i', '--invalidate', action='store_true',
                        help='Mark all updated stops as needing indexing')
    parser.add_argument('-v', '--verbose', action='count', default=2,
                        help='Increase verboseness of output')
    group = parser.add_argument_group('Database arguments')
    group.add_argument('-d', '--database', metavar='DB', default='nominatim',
                       help='Name of PostgreSQL database to connect (default: nominatim)')
    group.add_argument('-U', '--username', metavar='USER',
                       help='PostgreSQL user name')
    group.add_argument('-H', '--host', metavar='HOST',
                       help='Database server host name or socket location')
    group.add_argument('-P', '--port', metavar='PORT',
                       help='Database server port')
    group.add_argument('-p', '--password', metavar='PASSWORD',
                       help='Database password')

    parser.add_argument('infile', metavar='FILE',
                        help='CSV file with IFOPT data')

    return parser

# OSM node ID guaranteed not to clash with OSM internal IDs in the next ten years.
MIN_CUSTOM_ID = 10000000000


def insert_ifopt(conn, osm_id, ifopt, invalidate):
    """ Add the given IFOPT id to the extratags of the given OSM object.
        When invalidate is set, the status of the OSM object is set to
        needing an update. That forces, for example, a reimport into Photon.

        Returns true, if the OSM object could be successfully updated.
    """
    if not osm_id[0].lower() in ('n', 'r', 'w') or not osm_id[1:].isdigit() or not ifopt:
        return False

    osm_type = osm_id[0].upper()
    osm_obj_id = int(osm_id[1:])

    update_sql = """UPDATE placex
                        SET extratags = extratags || hstore ('ref:IFOPT', %s)"""
    if invalidate:
        update_sql += ", indexed_status = 2"
    update_sql += "WHERE osm_type = %s and osm_id = %s"

    with conn.cursor() as cur:
        cur.execute(update_sql, (ifopt, osm_type, osm_obj_id))
        return cur.rowcount > 0


def update_artificial(conn, node_id, names, address, extratags, lon, lat):
    """ Update an existing artificial node with new information, if necessary.
    """
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""SELECT place_id, name, address, extratags,
                              ST_X(geometry) as lon, ST_Y(geometry) as lat
                       FROM placex
                       WHERE osm_type = 'N' and osm_id = %s""",
                    (node_id, ))

        row = cur.fetchone()

        if not set(names.items()).issubset(set(row['name'].items())) \
           or set(row['address'].items()) != set(address.items()) \
           or row['extratags'].get('ref:IFOPT', '') != extratags['ref:IFOPT'] \
           or abs(row['lat'] - lat) > 0.000001 or abs(row['lon'] - lon) > 0.000001:
            cur.execute("""UPDATE placex
                           SET name = %s, address = %s, extratags = %s,
                               geometry='SRID=4326;POINT(%s %s)',
                               indexed_status = 2
                           WHERE place_id = %s
                    """,
                    (names, address, extratags, lon, lat, row['place_id']))



def insert_artificial(conn, node_id, names, address, extratags, lon, lat):
    """ Insert the given CSV row as an artificial node of type
        public_transport=platform into the Nominatim database.
    """
    with conn.cursor() as cur:
        cur.execute("""INSERT INTO placex (place_id, osm_type, osm_id,
                                           class, type, name, address, extratags,
                                           geometry)
                       VALUES (nextval('seq_place'), 'N', %s,
                               'public_transport', 'platform', %s, %s, %s,
                               'SRID=4326;POINT(%s %s)')
                    """, (node_id, names, address, extratags, lon, lat))


def import_pt(conn, csvfile, invalidate):
    """ Read the given CSV file of PT stops and apply it to the Nominatim
        database behind conneciton 'conn'. If 'invalidate' is set, then
        an update will be forced on the OSM objects, where the ref:IFOPT is set.
    """
    reader = csv.DictReader(csvfile, delimiter=',')

    osm_matched = 0
    external_added = 0
    external_updated = 0

    # Get the set of current external IFOPT nodes, so we know if to update
    # or insert.
    with conn.cursor() as cur:
        cur.execute("""SELECT osm_id, extratags->'ref:IFOPT' FROM placex
                       WHERE osm_type = 'N' and osm_id >= %s
                             and extratags ? 'ref:IFOPT'""",
                    (MIN_CUSTOM_ID, ))
        extra_ifopts = {row[1] : row[0] for row in cur}

    current_ext_id = max(extra_ifopts.values(), default=MIN_CUSTOM_ID) + 1

    done_external_ifopts = set()

    for row in reader:
        osm_id = row['osm_id']
        ifopt = row['globaleID']
        if osm_id and insert_ifopt(conn, osm_id, ifopt, invalidate):
            osm_matched += 1
            continue

        # Unknown OSM id, add as an external object.
        if ifopt in done_external_ifopts:
            continue # ignore duplicates

        lat = float(row['lat'])
        lon = float(row['lon'])
        address = {'county' : row['Landkreis'],
                   'city' : row['Gemeinde'],
                   'suburb': row['Ortsteil']}
        names = {'name': row['Haltestelle'],
                 'name:alt': row['Haltestelle_lang']}
        extratags = {'ref:IFOPT' : ifopt}

        if ifopt in extra_ifopts:
            update_artificial(conn, extra_ifopts[ifopt],
                              names, address, extratags, lon, lat)
            external_updated += 1

        else:
            insert_artificial(conn, current_ext_id,
                              names, address, extratags, lon, lat)
            current_ext_id += 1
            external_added += 1

        done_external_ifopts.add(ifopt)

    print(f"Matched: {osm_matched}, updated: {external_updated}, added: {external_added}")

    # Delete all external nodes that are not in the list anymore.
    to_delete = set(extra_ifopts.keys()) - done_external_ifopts
    if to_delete:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM placex WHERE osm_type = 'N' and osm_id = any(%s)",
                        ([extra_ifopts[i] for i in to_delete], ))
        print(f"Deleted external: {len(to_delete)}")


if __name__ == '__main__':
    parser = get_parser()
    args = parser.parse_args()

    logging.basicConfig(stream=sys.stderr,
                        format='{asctime} [{levelname}]: {message}',
                        style='{',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=max(3 - args.verbose, 1) * 10)

    conn = connect(args)

    if args.infile.endswith('.gz'):
        with gzip.open(args.infile, 'rt') as csvfile:
            ret = import_pt(conn, csvfile, args.invalidate)
    else:
        with open(args.infile, newline='') as csvfile:
            ret = import_pt(conn, csvfile, args.invalidate)
    conn.commit()
    conn.close()

    sys.exit(ret)
