## digitransit-ansible

Install stadtnavi's digitransit with ansible

- `make dev`: connects to the dev host and applies the playbook there
- `make production`
- `make infrastructure`
- `make monitoring`

### Monitoring

OTP is monitored by Prometheus and Grafana on https://monitoring.stadtnavi.eu. Please ask
@hbruch or @leonardehrenfried for access.

### Vault 

Secrets are encrypted with ansible vault. In order to run the above playbooks
you need to place a file called `vault-password` into the root of the repository
- it's ignored by version control.

Please get in touch with @leonardehrenfried to get the decryption key to paste
into this file.

#### Encrypting 

In order to add a new encrpted variable, use the following command:

```
ansible-vault encrypt_string --vault-password-file vault-password super-secure-text --name=my_secret_var
```

This prints an encrypted variable in ansible's yml syntax which you can paste into one of the vars files.

#### Decrypting

The easiest way is to look at the decrypted value is to view it on a host where it has been deployed
to, where it is stored in plain text.

### Digitransit target host requirements

This playbook has been tested with a Debian Buster (11) target only.

In order to execute the ansible playbook you need a user on the target host and `sudo`
must be installed (which is not the case when using the Debian minimal base image).
You also must enable [passwordless sudo](https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux)

#### DNS

In order for the automatic TLS certificate generation to work, you need to 
configure a DNS entry for the host.

On top of the main DNS entry, you also need up to three other ones:

- One that starts with `api.` which points to the exact same machine. This is used to 
proxy all non-UI related API requests to their corresponding docker containers.
- One for matomo
- If you want to install Photon on the server too, you need hostname for that too.

### Configuration files

The digitransit configuration files, that don't live inside docker containers,
are placed or symlinked into `/etc/digitransit`.

### Timers

This playbook uses systemd timers as a replacement for cron jobs.

If you want to list them run `systemctl list-timers`.

As of May 2020 this list as follows:

```
systemctl list-timers 
NEXT                          LEFT          LAST                          PASSED               UNIT                           ACTIVATES
Thu 2020-05-14 12:18:00 CEST  20s left      Thu 2020-05-14 12:16:01 CEST  1min 38s ago         thingsboard-to-parkapi.timer   thingsboard-to-parkapi.service
Thu 2020-05-14 23:00:00 CEST  10h left      Wed 2020-05-13 23:00:01 CEST  13h ago              data-builder.timer             data-builder.service
Fri 2020-05-15 00:00:00 CEST  11h left      Thu 2020-05-14 00:00:01 CEST  12h ago              docker-prune.timer             docker-prune.service
Fri 2020-05-15 02:00:00 CEST  13h left      Thu 2020-05-14 02:00:01 CEST  10h ago              digitransit-restart.timer      digitransit-restart.service
Fri 2020-05-15 02:15:00 CEST  13h left      Thu 2020-05-14 02:15:02 CEST  10h ago              tilemaker.timer                tilemaker.service
```

### Automatic graph builds

The script `build-graph` builds a new graph every night at 1 o'clock.
This is controlled by the systemd timer `graph-build` and if you want to modify
this, then edit `graph-build.timer` and `graph-build.service`.

### Common tasks

**Restarting digitransit**

`systemctl restart digitransit-docker-compose`

This also checks if there are newer images available on dockerhub and downloads
them prior to restarting. 

It also cleanly stops and removes the containers. This
is important because `hsl-map-server` cannot be stopped and restarted.

**Restarting a single digitransit container**

`restart-digitransit-container digitransit-ui`

**Viewing logs**

All logs are sent to `journald` for storage and automatic deletion. Here is
a list of common `journalctl` commands.

- Viewing *all* digitransit logs: `journalctl -u digitransit-docker-compose.service`
- Viewing digitransit-ui logs: `journalctl CONTAINER_NAME=digitransit-ui-hbnext`
- Viewing opentripplanner logs: `journalctl CONTAINER_NAME=opentripplanner`
- Viewing graph-build logs: `journalctl -u graph-build`
- Viewing POI import logs: `journalctl -u poi-import`
- Viewing weather stations import logs: `journalctl -u import-weather-stations`
- Viewing vehicle position forwarder logs: `journalctl -u gtfsrt2mqtt`
- Viewing thingsboard to parkapi transformer logs: `journalctl -u thingsboard-to-parkapi`

**Triggering a rebuild of the OTP graph**

`systemctl start graph-build`

A build is run every night but sometimes you want to trigger it manually.

**aliases**

To see the complete list of useful aliases check out [`alias.sh`](roles/base/templates/alias.sh).

## Subtopics

- [Adding another digitransit-ui instance](./docs/adding-a-ui-instance.md)
- [Upgrade Matomo](./docs/upgrade-matomo.md)
- [Vehicle Positions](./docs/vehicle-positions.md)
