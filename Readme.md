## digitransit-ansible

Install mfdz's digitransit with ansible

- `make vagrant`: starts a Vagrant VM and applies the digitransit playbook
- `make staging`: connects to the staging host and applies the playbook there

In order for this commands to work, you also need to place the ansible vault
password file onto your file system. Please get in touch with @leonardehrenfried
to get it.

### Digitransit target host requirements

This playbook has been tested with a Debian Buster (10) target only.

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

### Automatic graph builds

The docker container `data-builder` builds a new graph every night at 1 o'clock.
This is controlled by the systemd timer `data-builder` and if you want to modify
this, then edit `data-builder.timer` and `data-builder.service`.

The original script also uploads data to dockerhub but since mfdz's version contains
personally identifiable information we cannot do that. This means that the graph
build needs to happen on the same machine as digitransit runs.

The `data-builder` then tags the built image as `mfdz/opentripplanner-data-container-hb:test`
`mfdz/opentripplanner-data-container-hb:local`. The `local` tag is what
digitransit uses.

Since the `data-container` containers are quite large, the `docker-prune` timer
removes every night containers that have not been used for 3 days.

### Common tasks

**Restarting digitransit**

`systemctl restart digitransit-docker-compose`

This also checks if there are newer images available on dockerhub and downloads
them prior to restarting. 

It also cleanly stops and removes the containers. This
is important because `hsl-map-server` cannot be stopped and restarted.

**Triggering a rebuild of the OTP graph**

`systemctl restart data-builder`

A build is run every night but sometimes you want to trigger it instantly.

**aliases**

To see the complete list of useful aliases check out [`alias.sh`](roles/base/templates/alias.sh).


