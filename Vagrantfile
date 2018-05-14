# -*- mode: ruby -*-
# vi: set ft=ruby :

box = {
  :virtualbox => 'ubuntu/xenial64',
  :libvirt => 'elastic/ubuntu-16.04-x86_64'
}

nodes = [
  {
    :name   => "controller01",
    :roles  => [ "kube-master", "etcd",],
    :ip     => "10.10.10.3",
    :memory => 1024 * 8,
    :cpus   => 2
  },
  {
    :name   => "controller02",
    :roles  => [ "kube-master", "etcd",],
    :ip     => "10.10.10.4",
    :memory => 1024 * 8,
    :cpus   => 2
  },
  {
    :name   => "controller03",
    :roles  => [ "kube-master", "etcd",],
    :ip     => "10.10.10.5",
    :memory => 1024 * 8,
    :cpus   => 2
  },
  {
    :name   => "compute01",
    :roles  => [ "kube-node",],
    :ip     => "10.10.10.6",
    :memory => 1024 * 8,
    :cpus   => 2
  },
  {
    :name   => "compute02",
    :roles  => [ "kube-node",],
    :ip     => "10.10.10.7",
    :memory => 1024 * 8,
    :cpus   => 2
  },
]

provider = (ENV['VAGRANT_DEFAULT_PROVIDER'] || :virtualbox).to_sym
puts "[INFO] Provider: #{provider} "

if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  nodes.each do |node|
    $no_proxy += "," + node[:ip]
  end
  $subnet = "192.168.121"
  (1..255).each do |i|
    $no_proxy += ",#{$subnet}.#{i}"
  end
end

# Inventory file creation
File.open("etc/hosts.ini", "w") do |inventory_file|
  inventory_file.puts("[all:vars]\nansible_connection=ssh\nansible_ssh_user=vagrant\nansible_ssh_pass=vagrant\n\n[all]")
  nodes.each do |node|
    inventory_file.puts(node[:name])
  end
  inventory_file.puts("\n[kube-master]")
  nodes.each do |node|
    if node[:roles].include?("kube-master")
       inventory_file.puts(node[:name])
    end
  end
  inventory_file.puts("\n[kube-node]")
  nodes.each do |node|
    if node[:roles].include?("kube-node")
       inventory_file.puts(node[:name])
    end
  end
  inventory_file.puts("\n[etcd]")
  nodes.each do |node|
    if node[:roles].include?("etcd")
       inventory_file.puts(node[:name])
    end
  end
  inventory_file.puts("\n[k8s-cluster:children]\nkube-node\nkube-master")
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
    config.vm.define node[:name] do |nodeconfig|
      nodeconfig.vm.hostname = node[:name]
      nodeconfig.ssh.insert_key = false
      nodeconfig.vm.network :private_network, :ip => node[:ip], :type => :static
      nodeconfig.vm.provider 'virtualbox' do |v|
        v.customize ["modifyvm", :id, "--memory", node[:memory]]
        v.customize ["modifyvm", :id, "--cpus", node[:cpus]]
      end
      nodeconfig.vm.provider 'libvirt' do |v|
        v.memory = node[:memory]
        v.cpus = node[:cpus]
        v.nested = true
        v.cpu_mode = 'host-passthrough'
      end
      nodeconfig.vm.provision 'shell' do |s|
        s.path = "node.sh"
      end
    end
  end
  config.vm.define :installer do |installer|
    installer.vm.hostname = "installer"
    installer.ssh.insert_key = false
    installer.vm.network :private_network, :ip => "10.10.10.2", :type => :static
    installer.vm.synced_folder './etc', '/etc/kubespray/', create: true
    installer.vm.provision 'shell' do |s|
      s.path = "installer.sh"
    end
  end
end
