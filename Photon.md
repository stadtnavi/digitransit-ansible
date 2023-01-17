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

## Add all needed languages
All needed languages is now set in the `roles/photon/templates/photon.service` file as an environment variable called PHOTN_LANGUAGES.

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
curl "http://localhost:2322/api/?q=munchen&lang=de"
```



## Reset installation

see: `./roles/photon/templates/remove-nominatim-and-photon`

---

## Run the remotely on m900

* Append your `~/.ssh/config` file with the following configurations:
```
Host m900
    HostName 192.168.1.5
    User admin
    Port 22
        
Host photon-vm-m900
    ProxyJump m900
    HostName 192.168.122.212
    User ph
    Port 22
```
* Run `ssh-copy-id photon-vm-m900` then login and logout
* Build nominatim database with `make photon-remote`
* Then run the `sudo service photon start` command on the vm


# **Photon standalone**

## **In the Local Machine:**
- **Create VM by following the InstallVMGuide.md file (in the gi/devops from Codeberg):**
    - https://codeberg.org/gi/devops/src/branch/main/gitea/Documentations/InstallVMGuide.md
    - 64GB ram
    - 8 cores
    - 150G storage

- **Ask VM's IP address after Installation of the VM:**
    - Log in in the terminal:
        - `<username>` and `password`
        - `ip address`
    - Save the IP address

- **Open the terminal and use the ssh-copy-id command for not typing the password after ssh:**
    - `ssh-copy-id -i ~/.ssh/id_rsa.pub <username>@IP`
    - Type username's password

## **In the VM:**
- **Add sudo permission to user of vm:**
    - Give the sudo permission to the user in the terminal as root:
    - https://phpraxis.wordpress.com/2016/09/27/enable-sudo-without-password-in-ubuntudebian/
        - `su -l`
        - `adduser <user> sudo`
        - `apt-get install sudo`
        - `sudo visudo /etc/sudoers`
            - `<username> ALL=(ALL) NOPASSWD:ALL` to **the end of file**
        - `logout` or `exit`
        - `sudo apt-get install curl`

## **In the Local Machine:**
- **Open the new terminal:**
    - `cd ~/Desktop`
    - `mkdir git`
    - `cd git`
    - `git clone https://github.com/fahrgemeinschaft/digitransit-ansible.git`
    - `ċd digitransit-ansible`

- **Create virtual environment and install certain packages:**
    - `python3 -m virtualenv venv`
    - `. venv/bin/activate`
    - `pip3 install -r requirements.txt`
    - `ansible --help`

- **Add user to sudo group:**
    - `su` # enter root password here
    - `/sbin/usermod -aG sudo <username>`

- **Normal user should be able to run sudo commands without PW prompt**
    - `su` # enter root password here
    - `sudo visudo` /etc/sudoers
        - `username ALL=(ALL) NOPASSWD:ALL` to **the end of file**
    - `logout` or `exit`

- **Install geerlingguy.docker:**
    - `ansible-galaxy install geerlingguy.docker`

- **Add user to docker group:**
    - `sudo groupadd docker`
    - `su` # enter root password here
    - `/sbin/usermod -aG docker <username>`

- **Change ip address and hostname on the certain files:**
    - `nano inventory-local.yml`
    - `nano ansible-playbook.yml` OR `nano photon-playbook.yml`

- **Run the playbook:**
    - `make photon-local`

- **Open the new terminal again:**
    - `ssh <username>@IP`
    - `docker ps`
    - **Take the first 3 character of the nominatim**
    - `docker logs $3_character -f`
    - **Wait until the LOG shows the line:** (It may takes 40 minutes)
        - **database system is ready to accept connections**
    - `sudo service photon start`
    - `docker ps`
    - **Take the first 3 character of the photon**
    - `docker logs $3_character -f`
    - **Wait until the LOG shows the line:** (It may takes 5 minutes)
        - **de.komoot.photon.App - ES cluster is now ready.**
    - After them you can call the API with:
    - `curl "http://localhost:2322/api/?q=stuttgart&lang=de"`