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

## Run the playbook

```bash
ansible-playbook photon-playbook.yml
```