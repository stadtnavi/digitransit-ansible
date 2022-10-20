# Photon standalone

There is a role in the `roles/` directory called `photon`.

## Install ansible

```bash
python3 -m virtualenv venv
pip3 install -r requirements.txt
ansible --help
```

## Photon role

Some tasks are commented out for now:
- nginx
- pelias adapter

Might change later.

### Normal user should be able to un sudo commands
 
https://phpraxis.wordpress.com/2016/09/27/enable-sudo-without-password-in-ubuntudebian/


## Run the playbook

```bash
make photon
```

OR:

```bash
ansible-playbook photon-playbook.yml
```

## Reset installation

see: `./roles/photon/templates/remove-nominatim-and-photon`