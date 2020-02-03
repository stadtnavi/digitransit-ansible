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
  # host. We don't need it.
  config.vm.synced_folder ".", "/vagrant", disabled: true


  # Not sure if OS X hosts also use libvirt. Probably VirtualBox.
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 4
    libvirt.memory = 12288 # 12GB
  end

  # Run `ansible provision` to install digitransit in Ansible
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "digitransit.yml"
    ansible.compatibility_mode = "2.0"
  end
end
