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