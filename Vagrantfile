# -*- mode: ruby -*-
# vi: set ft=ruby :

box = {
  :virtualbox => 'ubuntu/xenial64',
  :libvirt => 'elastic/ubuntu-16.04-x86_64'
}

require 'yaml'
idf = ENV.fetch('IDF', 'config/pdf.yml')
nodes = YAML.load_file(idf)

# Inventory file creation
File.open("inventory/hosts.ini", "w") do |inventory_file|
  inventory_file.puts("[all:vars]\nansible_connection=ssh\nansible_ssh_user=vagrant\nansible_ssh_pass=vagrant\n\n[all]")
  nodes.each do |node|
    inventory_file.puts("#{node['name']}\tansible_ssh_host=#{node['ip']} ansible_ssh_port=22")
  end
  ['kube-master', 'kube-node', 'etcd', 'ovn-central', 'ovn-controller', 'virtlet'].each do|group|
    inventory_file.puts("\n[#{group}]")
    nodes.each do |node|
      if node['roles'].include?("#{group}")
        inventory_file.puts(node['name'])
      end
    end
  end
  inventory_file.puts("\n[k8s-cluster:children]\nkube-node\nkube-master")
end

provider = (ENV['VAGRANT_DEFAULT_PROVIDER'] || :virtualbox).to_sym
puts "[INFO] Provider: #{provider} "

if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  nodes.each do |node|
    $no_proxy += "," + node['ip']
  end
  $subnet = "192.168.121"
  # NOTE: This range is based on vagrant-libvirt network definition CIDR 192.168.121.0/27
  (0..31).each do |i|
    $no_proxy += ",#{$subnet}.#{i}"
  end
end


Vagrant.configure("2") do |config|
  config.vm.box =  box[provider]

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if not Vagrant.has_plugin?('vagrant-proxyconf')
      system 'vagrant plugin install vagrant-proxyconf'
      raise 'vagrant-proxyconf was installed but it requires to execute again'
    end
    config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
    config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
    config.proxy.no_proxy = $no_proxy
  end

  nodes.each do |node|
    config.vm.define node['name'] do |nodeconfig|
      nodeconfig.vm.hostname = node['name']
      nodeconfig.ssh.insert_key = false
      nodeconfig.vm.network :private_network, :ip => node['ip'], :type => :static
      nodeconfig.vm.provider 'virtualbox' do |v|
        v.customize ["modifyvm", :id, "--memory", node['memory']]
        v.customize ["modifyvm", :id, "--cpus", node['cpus']]
      end
      nodeconfig.vm.provider 'libvirt' do |v|
        v.memory = node['memory']
        v.cpus = node['cpus']
        v.nested = true
        v.cpu_mode = 'host-passthrough'
      end
      nodeconfig.vm.provision 'shell', inline: "swapoff -a"
    end
  end
  sync_type = "virtualbox"
  if provider == :libvirt
    if not Vagrant.has_plugin?('vagrant-libvirt')
      system 'vagrant plugin install vagrant-libvirt'
      raise 'vagrant-libvirt was installed but it requires to execute again'
    end
    sync_type = "nfs"
  end
  config.vm.define :installer, primary: true, autostart: false do |installer|
    installer.vm.hostname = "multicloud"
    #installer.ssh.insert_key = false
    installer.vm.network :private_network, :ip => "10.10.10.2", :type => :static
    installer.vm.provision 'shell' do |sh|
      sh.path =  "installer.sh"
      sh.args = ['-p', '-v', '-w', '/vagrant']
    end
  end
end
