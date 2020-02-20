.PHONY: vagrant staging production

PLAYBOOK_CMD:=ansible-playbook --vault-password-file vault-password

galaxy-install:
	ansible-galaxy install -r requirements.yml

vagrant: galaxy-install
	vagrant up
	vagrant provision

staging: galaxy-install
	${PLAYBOOK_CMD} -i staging digitransit.yml

production: galaxy-install
	${PLAYBOOK_CMD} -i production digitransit.yml

