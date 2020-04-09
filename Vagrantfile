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

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

require 'yaml'
pdf = File.dirname(__FILE__) + '/config/default.yml'
if File.exist?(File.dirname(__FILE__) + '/config/pdf.yml')
  pdf = File.dirname(__FILE__) + '/config/pdf.yml'
end
nodes = YAML.load_file(pdf)
vagrant_boxes = YAML.load_file(File.dirname(__FILE__) + '/distros_supported.yml')

# Inventory file creation
File.open(File.dirname(__FILE__) + "/inventory/hosts.ini", "w") do |inventory_file|
  inventory_file.puts("[all]")
  nodes.each do |node|
    inventory_file.puts(node['name'])
  end
  ['kube-master', 'kube-node', 'etcd', 'virtlet', 'qat-node', 'criu'].each do|group|
    inventory_file.puts("\n[#{group}]")
    nodes.each do |node|
      if node['roles'].include?("#{group}")
        inventory_file.puts("#{node['name']}\t\tansible_host=#{node['networks'][0]['ip']}\tip=#{node['networks'][0]['ip']}")
      end
    end
  end
  inventory_file.puts("\n[k8s-cluster:children]\nkube-node\nkube-master")
end

File.exists?("/usr/share/qemu/OVMF.fd") ? loader = "/usr/share/qemu/OVMF.fd" : loader = File.join(File.dirname(__FILE__), "OVMF.fd")
if not File.exists?(loader)
  system('curl -O https://download.clearlinux.org/image/OVMF.fd')
end

$krd_debug = ENV['KRD_DEBUG'] || "true"
$krd_network_plugin = ENV['KRD_NETWORK_PLUGIN'] || "flannel"
$krd_enable_multus = ENV['KRD_ENABLE_MULTUS'] || "false"
$krd_qat_plugin_mode = ENV['KRD_QAT_PLUGIN_MODE'] || "dpdk"
$krd_container_runtime = ENV['KRD_CONTAINER_RUNTIME'] || "docker"

$no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
nodes.each do |node|
  if node.has_key? "networks"
    node['networks'].each do |network|
      $no_proxy += "," + network['ip']
    end
  end
end
# NOTE: This range is based on vagrant-libvirt network definition CIDR 192.168.125.0/27
(1..31).each do |i|
  $no_proxy += ",192.168.125.#{i},10.0.2.#{i}"
end
$no_proxy += ",10.0.2.15,10.10.17.2"

# Discoverying host capabilities
$qat_devices = ""
$sriov_devices = ""
$qemu_version = ""
if which 'lspci'
  if $krd_qat_plugin_mode == "kernel"
    $qat_devices = `for i in 0434 0435 37c8 6f54 19e2; do lspci -d 8086:$i -m; done|awk '{print $1}'`
  else
    $qat_devices = `for i in 0442 0443 37c9 19e3; do lspci -d 8086:$i -m; done|awk '{print $1}'`
  end
  $sriov_devices = `lspci | grep "Ethernet .* Virtual Function"|awk '{print $1}'`
end
if which 'qemu-system-x86_64'
  $qemu_version = `qemu-system-x86_64 --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/'`
end

Vagrant.configure("2") do |config|
  config.vm.provider "libvirt"
  config.vm.provider "virtualbox"

  config.vm.provider 'libvirt' do |v|
    v.management_network_address = "192.168.125.0/27"
    v.management_network_name = "krd-mgmt-net"
    v.random_hostname = true
  end
  config.ssh.insert_key = false
  config.vm.synced_folder './', '/vagrant'

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if Vagrant.has_plugin?('vagrant-proxyconf')
      config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
      config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
      config.proxy.no_proxy = $no_proxy
      config.proxy.enabled = { docker: false }
    end
  end

  config.vm.provider "virtualbox" do |v|
    v.gui = false
  end

  nodes.each do |node|
    config.vm.define node['name'] do |nodeconfig|
      nodeconfig.vm.hostname = node['name']
      if node.has_key? "networks"
        node['networks'].each do |network|
          nodeconfig.vm.network :private_network, :ip => network['ip'], :type => :static,
            libvirt__network_name: network['name']
        end
      end # networks
      [:virtualbox, :libvirt].each do |provider|
        nodeconfig.vm.provider provider do |p, override|
          p.cpus = node['cpus']
          p.memory = node['memory']
        end
      end
      nodeconfig.vm.box =  vagrant_boxes[node["os"]["name"]][node["os"]["release"]]["name"]
      nodeconfig.vm.box_version = vagrant_boxes[node["os"]["name"]][node["os"]["release"]]["version"]
      nodeconfig.vm.provider 'virtualbox' do |v, override|
        if node['roles'].include?("virtlet")
          v.customize ["modifyvm", :id, "--nested-hw-virt","on"]
        end
        if node.has_key? "volumes"
          node['volumes'].each do |volume|
            $volume_file = "#{node['name']}-#{volume['name']}.vdi"
            unless File.exist?($volume_file)
              v.customize ['createmedium', 'disk', '--filename', $volume_file, '--size', (volume['size'] * 1024)]
            end
            v.customize ['storageattach', :id, '--storagectl', vagrant_boxes[node["os"]["name"]][node["os"]["release"]]["vb_controller"], '--port', 1, '--device', 0, '--type', 'hdd', '--medium', $volume_file]
          end
        end # volumes
      end # virtualbox
      nodeconfig.vm.provider 'libvirt' do |v, override|
        v.disk_bus = "sata"
        if node['roles'].include?("virtlet")
          v.nested = true
        end
        if node['os'] == "clearlinux"
          v.loader = loader
        end
        v.cpu_mode = 'host-passthrough'
        if node.has_key? "volumes"
          node['volumes'].each do |volume|
            v.storage :file, :bus => 'sata', :device => volume['name'], :size => volume['size']
          end
        end # volumes
        # Intel Corporation Persistent Memory
        if Gem::Version.new($qemu_version) > Gem::Version.new('2.6.0')
          if node.has_key? "pmem"
            v.qemuargs :value => '-machine'
            v.qemuargs :value => 'pc,accel=kvm,nvdimm=on'
            v.qemuargs :value => '-m'
            v.qemuargs :value => "#{node['pmem']['size']},slots=#{node['pmem']['slots']},maxmem=#{node['pmem']['max_size']}"
            node['pmem']['vNVDIMMs'].each do |vNVDIMM|
              v.qemuargs :value => '-object'
              v.qemuargs :value => "memory-backend-file,id=#{vNVDIMM['mem_id']},share=#{vNVDIMM['share']},mem-path=#{vNVDIMM['path']},size=#{vNVDIMM['size']}"
              v.qemuargs :value => '-device'
              v.qemuargs :value => "nvdimm,id=#{vNVDIMM['id']},memdev=#{vNVDIMM['mem_id']},label-size=2M"
            end
          end
        end
        # Intel Corporation QuickAssist Technology
        if node.has_key? "qat_dev"
          node['qat_dev'].each do |dev|
            if $qat_devices.include? dev.to_s
              bus=dev.split(':')[0]
              slot=dev.split(':')[1].split('.')[0]
              function=dev.split(':')[1].split('.')[1]
              v.pci :bus => "0x#{bus}", :slot => "0x#{slot}", :function => "0x#{function}"
            end
          end
        end
        # Non-Uniform Memory Access (NUMA)
        if node.has_key? "numa_nodes"
          $numa_nodes = []
          node['numa_nodes'].each do |numa_node|
            numa_node['cpus'].strip!
            $numa_nodes << {:cpus=>numa_node['cpus'], :memory=>"#{numa_node['memory']}"}
          end
          v.numa_nodes = $numa_nodes
        end
        # Single Root I/O Virtualization (SR-IOV)
        if node.has_key? "sriov_dev"
          node['sriov_dev'].each do |dev|
            if $sriov_devices.include? dev.to_s
              bus=dev.split(':')[0]
              slot=dev.split(':')[1].split('.')[0]
              function=dev.split(':')[1].split('.')[1]
              v.pci :bus => "0x#{bus}", :slot => "0x#{slot}", :function => "0x#{function}"
            end
          end
        end
      end # libvirt
      nodeconfig.vm.provision 'shell', inline: <<-SHELL
        mkdir -p /root/.ssh
        cat /vagrant/insecure_keys/key.pub | tee /root/.ssh/authorized_keys
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        sudo sed -i '/^PermitRootLogin no/d' /etc/ssh/sshd_config
      SHELL
      $volume_mounts_dict = ''
      if node.has_key? "volumes"
        node['volumes'].each do |volume|
          if volume.has_key? "mount"
            $volume_mounts_dict += "#{volume['name']}=#{volume['mount']},"
          end
        end
      end
      nodeconfig.vm.provision 'shell' do |sh|
        sh.env = {
          'KRD_DEBUG': "#{$krd_debug}",
          'KRD_CONTAINER_RUNTIME': "#{$krd_container_runtime}"
        }
        sh.path =  "node.sh"
        sh.args = ['-v', $volume_mounts_dict[0...-1]]
      end
      if node['os'] == "centos"
        nodeconfig.vm.provision :reload
      end
    end
  end # node.each

  config.vm.define :installer, primary: true, autostart: false do |installer|
    installer.vm.hostname = "undercloud"
    installer.vm.box =  vagrant_boxes["ubuntu"]["xenial"]["name"]
    installer.vm.network :forwarded_port, guest: 9090, host: 9090

    [:virtualbox, :libvirt].each do |provider|
    installer.vm.provider provider do |p|
        p.cpus = 1
        p.memory = 1024
      end
    end

    # NOTE: A private network set up is required by NFS. This is due
    # to a limitation of VirtualBox's built-in networking.
    installer.vm.network "private_network", ip: "10.10.17.2"
    installer.vm.provision 'shell', privileged: false, inline: <<-SHELL
      cd /vagrant
      sudo mkdir -p /root/.ssh/
      sudo cp insecure_keys/key /root/.ssh/id_rsa
      cp insecure_keys/key ~/.ssh/id_rsa
      sudo chmod 400 /root/.ssh/id_rsa
      chown "$USER" ~/.ssh/id_rsa
      chmod 400 ~/.ssh/id_rsa
    SHELL
    installer.vm.provision 'shell', privileged: false do |sh|
      sh.env = {
        'KRD_DEBUG': "#{$krd_debug}",
        'KRD_ENABLE_MULTUS': "#{$krd_enable_multus}",
        'KRD_QAT_PLUGIN_MODE': "#{$krd_qat_plugin_mode}",
        'KRD_NETWORK_PLUGIN': "#{$krd_network_plugin}",
        'KRD_CONTAINER_RUNTIME': "#{$krd_container_runtime}"
      }
      sh.inline = <<-SHELL
        for krd_var in $(printenv | grep KRD_); do echo "export $krd_var" | sudo tee --append /etc/environment ; done
        cd /vagrant/
        ./krd_command.sh -a install_k8s -a install_cockpit | tee vagrant_init.log
      SHELL
    end
  end # installer
end
