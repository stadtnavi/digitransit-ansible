### digitransit-ansible

Install mfdz's digitransit with ansible

- `make vagrant`: starts a Vagrant VM and applies the digitransit playbook
- `make staging`: connects to the staging host and applies the playbook there

#### Interesting commands inside the provisioned host

- `digitransit-logs`: docker-compose logs
