# -*- mode: ruby -*-
# vi: set ft=ruby :

# Configurable number of worker nodes
NUM_WORKERS = 2

Vagrant.configure("2") do |config|
  # Base box for all VMs
  config.vm.box = "bento/ubuntu-24.04"

  # Control Node Configuration
  config.vm.define "ctrl" do |ctrl|
    ctrl.vm.hostname = "ctrl"
    
    # Host-only network for internal cluster communication
    # Fixed IP as per assignment requirements
    ctrl.vm.network "private_network", ip: "192.168.56.100"
    
    # VirtualBox specific settings
    ctrl.vm.provider "virtualbox" do |vb|
      vb.name = "k8s-ctrl"
      vb.memory = "4096"
      vb.cpus = 1
    end
  end

  # Worker Nodes Configuration
  (1..NUM_WORKERS).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.hostname = "node-#{i}"
      
      # Host-only network - sequential IPs starting from .101
      # Fixed IPs as per assignment requirements
      node.vm.network "private_network", ip: "192.168.56.#{100 + i}"
      
      # VirtualBox specific settings
      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-node-#{i}"
        vb.memory = "6144"
        vb.cpus = 2
      end
    end

  end

  # Common provisioning for all VMs
  config.vm.provision "shell", inline: <<-SHELL
    # Add hosts entries for hostname resolution
    echo "192.168.56.100 ctrl" >> /etc/hosts
    for i in $(seq 1 #{NUM_WORKERS}); do
      echo "192.168.56.$((100 + i)) node-$i" >> /etc/hosts
    done
    
    echo "Base provisioning complete"
  SHELL
end