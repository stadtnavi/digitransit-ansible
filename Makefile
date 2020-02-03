install:
	ansible-galaxy install -r requirements.yml
	vagrant provision
