.PHONY: vagrant staging

galaxy-install:
	ansible-galaxy install -r requirements.yml

vagrant: galaxy-install
	vagrant up
	vagrant provision

staging: galaxy-install
	ansible-playbook --vault-password-file vault-password -i staging digitransit.yml

