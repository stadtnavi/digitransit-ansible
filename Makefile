.PHONY: vagrant
vagrant:
	ansible-galaxy install -r requirements.yml
	vagrant up
	vagrant provision
