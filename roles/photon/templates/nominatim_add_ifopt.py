#!/usr/bin/env python3
"""
Adds the IFOPT ID from an external CSV to a Nominatim database.

Two columsn are used from the input CSV:
 * osm_id must contain a OSM ID of the format <n|r|w><id>
 * ifopt_id must contain the full IFOPT (inkluding country code)

All other columns in the CSV are simply ignored.

The ID is added to the placex table of the Nominatim database in the
extratags column as 'ref:IFOPT'. Existing IFOPT IDs are overwritten.
See also https://wiki.openstreetmap.org/wiki/Key:ref:IFOPT.
"""
from argparse import ArgumentParser, RawDescriptionHelpFormatter
import csv
import logging
import sys

import psycopg2

LOG = logging.getLogger()

def connect(args):
    """ Create a connection from the given command line arguments.
    """
    return psycopg2.connect(dbname=args.database, user=args.username,
                            host=args.host, port=args.port)


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

    parser.add_argument('infile', metavar='FILE',
                        help='CSV file with IFOPT data')

    return parser

def get_ids(row):
    if 'osm_id' not in row:
        LOG.critical("CSV has no column 'osm_id'.")
        sys.exit(1)
    if 'ifopt_id' not in row:
        LOG.critical("CSV has no column 'ifopt_id'.")
        sys.exit(1)

    osm_id = row['osm_id']

    if not osm_id or osm_id[0] not in 'nrwNRW' or not osm_id[1:].isdigit():
        LOG.warning("OSM ID '%s' does not have format <nrw><id>. Ignored.", osm_id)
        return None, None, None

    return osm_id[0].upper(), osm_id[1:], row['ifopt_id']

def import_ifopts(conn, infile, invalidate):
    with open(infile, newline='') as csvfile:
        reader = csv.DictReader(csvfile)

        total_rows = 0
        updated_ids = 0
        bad_rows = 0

        update_sql = """UPDATE placex
                        SET extratags = extratags || hstore ('ref:IFOPT', %s)"""
        if invalidate:
            update_sql += ", indexed_status = 2"
        update_sql += "WHERE osm_type = %s and osm_id = %s"

        with conn.cursor() as cur:
            for row in reader:
                osm_type, osm_id, ifopt_id = get_ids(row)
                if osm_type is not None:
                    cur.execute(update_sql, (ifopt_id, osm_type, osm_id))
                    updated_ids += cur.rowcount
                else:
                    bad_rows += 1
                total_rows += 1
        conn.commit()

    LOG.info("Total rows: %d.  Updated rows: %d.", total_rows, updated_ids)
    if bad_rows > 0:
        LOG.WARNING("%d rows had an error.", bad_rows)



if __name__ == '__main__':
    parser = get_parser()
    args = parser.parse_args()

    logging.basicConfig(stream=sys.stderr,
                        format='{asctime} [{levelname}]: {message}',
                        style='{',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        level=max(3 - args.verbose, 1) * 10)

    conn = connect(args)
    ret = import_ifopts(conn, args.infile, args.invalidate)
    conn.close()

    sys.exit(ret)
