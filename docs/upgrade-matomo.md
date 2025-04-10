# Upgrading Matomo 

In order to upgrade Matomo, follow these steps:

- Change the version in the Ansible config like this: https://github.com/stadtnavi/digitransit-ansible/commit/f5d3b6cdc6d9cbab9025758994b7f050ef3cd3a2
- Provision the server with `make dev` or `make prod`
- Then log into Matomo and migrate in the UI
    - This will attempt a database migration but this may time out. That's not particularly bad. Just follow the next step.
- Make sure that the database is migrated with the following commands:
  ```
  docker exec -it matomo_app_1 /bin/sh
  php /var/www/html/console core:update
  ```

# Restore Matomo backup

- On the old host run `sudo systemctl start matomo-backup`
  - This will generate a bzip2 file into the Nextcloud instance on nextcloud.leonard.io
- Create a public sharing link in Nextcloud
- On the new host go into the Matomo DB container: `docker exec -it matomo-db-1 /bin/bash`
- Install wget and bzip2 if they aren't already `apt install wget bzip2`
- Download Matomo SQL archive: `wget https://nextcloud.leonard.io/s/KETpWMM6C3brTcN/download/matomo-db-2025-04-10.sql.bz2`
- Unpack the archive: `bzip2 -dk matomo-db-2025-04-10.sql.bz2`
- Restore the DB dump: `mysql -u matomo -p -h localhost < matomo-db-2025-04-10.sql` (Get password from docker-compose file)