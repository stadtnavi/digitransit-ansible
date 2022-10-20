# Photon standalone

There is a role in the `roles/` directory called `photon`.

## Install ansible

```bash
python3 -m virtualenv venv
. venv/bin/activate
pip3 install -r requirements.txt
ansible --help
```

## Photon role

Some tasks are commented out for now:
- nginx
- pelias adapter

Might change later.

## Add user to sudo group

```bash
su # enter root password here
/sbin/usermod -aG sudo $username
```


### Normal user should be able to run sudo commands without PW prompt
 
https://phpraxis.wordpress.com/2016/09/27/enable-sudo-without-password-in-ubuntudebian/


## Install geerlingguy.docker

```bash
ansible-galaxy install geerlingguy.docker
```


## Add user to docker group

```bash
su # enter root password here
/sbin/usermod -aG docker $username
```

## Run the playbook

If you have a local VM, you can run the follwoing make command.

```bash
make photon-local
```

OR:

```bash
ansible-playbook photon-playbook.yml
```


After nominatim data has been read and you see this line:
`database system is ready to accept connections`

You must also start the photon service with:

```bash
sudo service photon start
```

After photon has read the nominatim data and you see this line:
`de.komoot.photon.App - ES cluster is now ready.`


You can call the api with:

```bash
curl "http://localhost:2322/api/?q=munchen&lang=ede"
```



## Reset installation

see: `./roles/photon/templates/remove-nominatim-and-photon`