# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|

  config.vm.box = "debian/buster64"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # Disable default shared folder as it's causing me problems on my Fedora
  # host.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Run `ansible provision` to install digitransit in Ansible
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "digitransit.yml"
  end
end
