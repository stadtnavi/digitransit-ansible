### digitransit-ansible

Install mfdz's digitransit with ansible

- `make vagrant`: starts a Vagrant VM and applies the digitransit playbook
- `make staging`: connects to the staging host and applies the playbook there

#### Host requirements

This playbook has been tested with a Debian Buster (10) host only.

In order to execute the ansible playbook you need a user on the host and `sudo`
must be installed (which is not the case when using the Debian minimal base image).
You also must enable (passwordless sudo)[https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux]

##### DNS

In order for the automatic TLS certificate generation to work, you need to 
configure a DNS entry for the host.

On top of the main DNS entry, you also need a second one, that starts with
`api.` which points to the exact same machine. This is used to proxy all 
non-UI related API requests to their corresponding docker containers.

#### Configuration files

All interesting configuration files, that don't live inside docker containers,
are placed or symlinked into `/etc/digitransit`.

#### Interesting commands inside the provisioned host

- `digitransit-logs`: docker-compose logs


