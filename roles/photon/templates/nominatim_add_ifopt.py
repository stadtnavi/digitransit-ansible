#!/usr/bin/env python3
"""
Add missing PT information to a Nominatim database.

The script expects a CSV file with the following fields:

 * Landkreis  - (optional) address county
 * Gemeinde   - (optional) address city
 * Ortsteil   - (optional) address district
 * Haltestelle - name
 * Haltestelle_lang - alt_name
 * GlobaleId - IFOPT ID
 * zhv_lat, zhv_lon  - Geographic location
 * osm_id    - OSM id of the form <nwr><id>
 * match_state - (optional) Kind of match.

For each field, the script first tries to find the corresponding OSM object
in the Nominatim database and add the ifopt, if necessary. If no object
is found or there was no matching OSM object available in the first place,
then an artificial object is added using the name, address and position
information from the CSV.

To use the script in on an existing Photon export with updates:

 * Make sure Photon is set up for updates (see -nominatim-update-init-for)
 * (Updates only) run OSM update on Nominatim database.
 * Run script against the Nominatim database.
 * Run address processing: nominatim index
 * Run photon update script.

If you want to force all involved stops to be reindexed and reimported into
Photon, run this scripts with '-i'. This is only necessary in the rare case
when the Nominatim and Photon database seem to be out of sync for some reason.

"""
from argparse import ArgumentParser, RawDescriptionHelpFormatter
from collections import Counter
import csv
import gzip
import logging
import sys

import psycopg
import psycopg.types.hstore

LOG = logging.getLogger()


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
MIN_CUSTOM_ID = 50000000000
# Mapping of rows onto address details.
# Presence of the rows is still optional, so feel free to add rows that only
#  present in some of the CSV data.
ADDRESS_MAPPING = [('Landkreis', 'county'),
                   ('Gemeinde', 'city'),
                   ('Ortsteil', 'suburb')]
# Match types where to just drop the entire line
MATCH_DROP = ('NO_MATCH_AND_SEEMS_UNSERVED', 'MATCHED_THOUGH_DISTANT')


def insert_ifopt(conn, osm_id, ifopt, names, invalidate):
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
                    SET extratags = coalesce(extratags, ''::hstore) || hstore ('ref:IFOPT', %(ifopt)s), """
    if invalidate:
        update_sql += "indexed_status = 2"
    else:
        update_sql += "indexed_status = CASE WHEN extratags->'ref:IFOPT' = %(ifopt)s THEN 0 ELSE 2 END"
    update_sql += """ WHERE osm_type = %(osm_type)s and osm_id = %(osm_id)s
                      RETURNING name
                  """

    with conn.cursor() as cur:
        cur.execute(update_sql,
                    {'ifopt': ifopt, 'osm_type': osm_type, 'osm_id': osm_obj_id})
        for row in cur:
            osm_names = row[0]
            if osm_names is not None:
                return True
            break
        else:
            return False

        # Name missing in OSM so add the external one.
        cur.execute("""UPDATE placex SET name = %s, indexed_status = 2
                       WHERE osm_type = %s and osm_id = %s
                    """, (names, osm_type, osm_obj_id))
        return True


def update_artificial(conn, node_id, names, address, extratags, lon, lat, invalidate):
    """ Update an existing artificial node with new information, if necessary.
    """
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute("""SELECT place_id, name, address, extratags,
                              ST_X(geometry) as lon, ST_Y(geometry) as lat
                       FROM placex
                       WHERE osm_type = 'N' and osm_id = %s""",
                    (node_id, ))

        row = cur.fetchone()

        if invalidate or not set(names.items()).issubset(set(row['name'].items())) \
           or set(row['address'].items()) != set(address.items()) \
           or row['extratags'].get('ref:IFOPT', '') != extratags['ref:IFOPT'] \
           or abs(row['lat'] - lat) > 0.000001 or abs(row['lon'] - lon) > 0.000001:
            cur.execute("""UPDATE placex
                           SET name = %s, address = %s, extratags = %s,
                               geometry=ST_SetSRID(ST_MakePoint(%s, %s), 4326),
                               indexed_status = 2
                           WHERE place_id = %s
                    """,
                    (names, address, extratags, lon, lat, row['place_id']))



def insert_artificial(conn, node_id, names, address, extratags, lon, lat):
    """ Insert the given CSV row as an artificial node of type
        public_transport=stop into the Nominatim database.
    """
    with conn.cursor() as cur:
        cur.execute("""INSERT INTO placex (place_id, osm_type, osm_id,
                                           class, type, name, address, extratags,
                                           geometry)
                       VALUES (nextval('seq_place'), 'N', %s,
                               'public_transport', 'stop', %s, %s, %s,
                               ST_SetSRID(ST_MakePoint(%s, %s), 4326))
                    """, (node_id, names, address, extratags, lon, lat))


def get_existing_externals(conn):
    """ Get the set of current external IFOPT nodes, so we know if to update
        or insert.
    """
    with conn.cursor() as cur:
        cur.execute("""SELECT osm_id, extratags->'ref:IFOPT' as ifopt FROM placex
                       WHERE osm_type = 'N' and osm_id >= %s
                             and extratags ? 'ref:IFOPT'""",
                    (MIN_CUSTOM_ID, ))
        return {row[1] : row[0] for row in cur}


def import_pt(conn, csvfile, invalidate):
    """ Read the given CSV file of PT stops and apply it to the Nominatim
        database behind connection 'conn'. If 'write_update_table' is set, then
        the IDs of changed objects will be written into the update tables of
        Photon, so that it can update itself later.
    """
    reader = csv.DictReader(csvfile, delimiter=',')

    osm_matched = 0
    external_added = 0
    external_updated = 0

    extra_ifopts = get_existing_externals(conn)
    current_ext_id = max(extra_ifopts.values(), default=MIN_CUSTOM_ID) + 1
    done_external_ifopts = set()

    for row in reader:
        if row.get('match_state') in MATCH_DROP:
            continue

        osm_id = row['osm_id']
        ifopt = row['GlobaleId']
        names = {'name': row['Haltestelle']}
        if row['Haltestelle'] != row['Haltestelle_lang']:
            names['name:alt'] = row['Haltestelle_lang']
        if osm_id and insert_ifopt(conn, osm_id, ifopt, names, invalidate):
            osm_matched += 1
            continue

        # Unknown OSM id, add as an external object.
        if ifopt in done_external_ifopts:
            continue # ignore duplicates

        lat = float(row['zhv_lat'])
        lon = float(row['zhv_lon'])
        address = {addr_type: row[row_name]
                   for row_name, addr_type in ADDRESS_MAPPING if row.get(row_name)}
        extratags = {'ref:IFOPT' : ifopt}

        if ifopt in extra_ifopts:
            update_artificial(conn, extra_ifopts[ifopt],
                              names, address, extratags, lon, lat, invalidate)
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


def main():
    parser = get_parser()
    args = parser.parse_args()

    logging.basicConfig(stream=sys.stderr,
                        format='{asctime} [{levelname}]: {message}',
                        style='{',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=max(3 - args.verbose, 1) * 10)

    with psycopg.connect(dbname=args.database, user=args.username,
                         host=args.host, port=args.port, password=args.password) as conn:
        info = psycopg.types.TypeInfo.fetch(conn, "hstore")
        psycopg.types.hstore.register_hstore(info, conn)

        if args.infile.endswith('.gz'):
            ctx = gzip.open(args.infile, 'rt')
        else:
            ctx = open(args.infile, newline='')

        with ctx as csvfile:
            return import_pt(conn, csvfile, args.invalidate)


if __name__ == '__main__':
    sys.exit(main())
