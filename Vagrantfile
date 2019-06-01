# -*- mode: ruby -*-
# vi: set ft=ruby :
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

box = {
  :virtualbox => {
    :ubuntu => { :name => 'elastic/ubuntu-16.04-x86_64', :version=> '20180708.0.0' },
    :centos => { :name => 'generic/centos7', :version=> '1.9.2' },
    :opensuse => { :name => 'opensuse/openSUSE-42.1-x86_64', :version=> '1.0.1' },
    :clearlinux => { :name => 'AntonioMeireles/ClearLinux', :version=> '28510' }
  },
  :libvirt => {
    :ubuntu => { :name => 'elastic/ubuntu-16.04-x86_64', :version=> '20180210.0.0' },
    :centos => { :name => 'centos/7', :version=> '1901.01' },
    :opensuse => { :name => 'opensuse/openSUSE-42.1-x86_64', :version=> '1.0.0' },
    :clearlinux => { :name => 'AntonioMeireles/ClearLinux', :version=> '28510' }
  }
}

require 'yaml'
pdf = File.dirname(__FILE__) + '/config/default.yml'
if File.exist?(File.dirname(__FILE__) + '/config/pdf.yml')
  pdf = File.dirname(__FILE__) + '/config/pdf.yml'
end
nodes = YAML.load_file(pdf)

# Inventory file creation
File.open(File.dirname(__FILE__) + "/inventory/hosts.ini", "w") do |inventory_file|
  inventory_file.puts("[all]")
  nodes.each do |node|
    inventory_file.puts(node['name'])
  end
  ['kube-master', 'kube-node', 'etcd', 'ovn-central', 'ovn-controller', 'virtlet', 'qat-node'].each do|group|
    inventory_file.puts("\n[#{group}]")
    nodes.each do |node|
      if node['roles'].include?("#{group}")
        inventory_file.puts(node['name'])
      end
    end
  end
  inventory_file.puts("\n[k8s-cluster:children]\nkube-node\nkube-master")
end

distro = (ENV['KRD_DISTRO'] || :ubuntu).to_sym
puts "[INFO] Linux Distro: #{distro} "

if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  nodes.each do |node|
    if node.has_key? "networks"
      node['networks'].each do |network|
        $no_proxy += "," + network['ip']
      end
    end
  end
  # NOTE: This range is based on vagrant-libvirt network definition CIDR 192.168.121.0/27
  (1..31).each do |i|
    $no_proxy += ",192.168.121.#{i},10.0.2.#{i}"
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider "libvirt"
  config.vm.provider "virtualbox"

  config.vm.provider 'virtualbox' do |v, override|
    override.vm.box =  box[:virtualbox][distro][:name]
    override.vm.box_version = box[:virtualbox][distro][:version]
  end
  config.vm.provider 'libvirt' do |v, override|
    override.vm.box =  box[:libvirt][distro][:name]
    override.vm.box_version = box[:libvirt][distro][:version]
    v.nested = true
    v.cpu_mode = 'host-passthrough'
    v.management_network_address = "192.168.121.0/27"
    v.management_network_name = "krd-mgmt-net"
    v.random_hostname = true
  end
  config.ssh.insert_key = false

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if Vagrant.has_plugin?('vagrant-proxyconf')
      config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
      config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
      config.proxy.no_proxy = $no_proxy
      config.proxy.enabled = { docker: false }
    end
  end

  nodes.each do |node|
    config.vm.define node['name'] do |nodeconfig|
      nodeconfig.vm.hostname = node['name']
      if node.has_key? "networks"
        node['networks'].each do |network|
          nodeconfig.vm.network :private_network, :ip => network['ip'], :type => :static,
            libvirt__network_name: network['name']
        end
      end
      nodeconfig.vm.provider 'virtualbox' do |v, override|
        v.customize ["modifyvm", :id, "--memory", node['memory']]
        v.customize ["modifyvm", :id, "--cpus", node['cpus']]
        if node.has_key? "volumes"
          node['volumes'].each do |volume|
            $volume_file = "#{node['name']}-#{volume['name']}.vdi"
            unless File.exist?($volume_file)
              v.customize ['createmedium', 'disk', '--filename', $volume_file, '--size', volume['size']]
            end
            v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', $volume_file]
          end
        end
      end # virtualbox
      nodeconfig.vm.provider 'libvirt' do |v, override|
        v.memory = node['memory']
        v.cpus = node['cpus']
        nodeconfig.vm.provision 'shell' do |sh|
          sh.path =  "node.sh"
          if node.has_key? "volumes"
            $volume_mounts_dict = ''
            node['volumes'].each do |volume|
              $volume_mounts_dict += "#{volume['name']}=#{volume['mount']},"
              $volume_file = "./#{node['name']}-#{volume['name']}.qcow2"
              v.storage :file, :bus => 'sata', :device => volume['name'], :size => volume['size']
            end
            sh.args = ['-v', $volume_mounts_dict[0...-1]]
          end
        end
      end # libvirt
      nodeconfig.vm.provision 'shell' do |sh|
        sh.inline = <<-SHELL
          mkdir -p /root/.ssh
          cat /vagrant/insecure_keys/key.pub | tee /root/.ssh/authorized_keys
          chmod og-wx /root/.ssh/authorized_keys
        SHELL
      end
    end 
  end # node.each

  config.vm.define :installer, primary: true, autostart: false do |installer|
    installer.vm.hostname = "undercloud"
    installer.vm.synced_folder './', '/vagrant'
    installer.vm.provision 'shell', privileged: false do |sh|
      sh.inline = <<-SHELL
        cd /vagrant
        sudo mkdir -p /root/.ssh/
        sudo cp insecure_keys/key /root/.ssh/id_rsa
        cp insecure_keys/key ~/.ssh/id_rsa
        sudo chmod 400 /root/.ssh/id_rsa
        chown "$USER" ~/.ssh/id_rsa
        chmod 400 ~/.ssh/id_rsa
      SHELL
    end
    installer.vm.provision 'shell', privileged: false do |sh|
      sh.env = {
        'KRD_DEBUG': 'true'
      }
      sh.inline = <<-SHELL
        cd /vagrant/
        ./krd_command.sh -a install_k8s  -a install_rundeck | tee vagrant_init.log
      SHELL
    end
  end # installer
end
