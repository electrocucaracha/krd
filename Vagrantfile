# frozen_string_literal: true

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
  exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
  ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

require "yaml"
pdf = "#{File.dirname(__FILE__)}/config/default.yml"
pdf = "#{File.dirname(__FILE__)}/config/pdf.yml" if File.exist?("#{File.dirname(__FILE__)}/config/pdf.yml")
nodes = YAML.load_file(pdf)
vagrant_boxes = YAML.load_file("#{File.dirname(__FILE__)}/distros_supported.yml")
installer_box = vagrant_boxes["ubuntu"]["jammy"]

# Inventory file creation
etchosts_dict = ""
File.open("#{File.dirname(__FILE__)}/inventory/hosts.ini", "w") do |inventory_file|
  inventory_file.puts("[all]")
  nodes.each do |node|
    inventory_file.puts("#{node['name']}\t\tansible_host=#{node['networks'][0]['ip']}\tip=#{node['networks'][0]['ip']}")
    etchosts_dict += "#{node['networks'][0]['ip']}-#{node['name']},"
  end
  %w[kube-master kube-node etcd qat-node criu].each do |group|
    inventory_file.puts("\n[#{group}]")
    nodes.each do |node|
      inventory_file.puts(node["name"]) if node["roles"].include?(group.to_s)
    end
  end
  inventory_file.puts("\n[k8s-cluster:children]\nkube-node\nkube-master")
end

system("echo -e \"\n\n\n\" | ssh-keygen -f #{File.dirname(__FILE__)}/insecure_keys/key -t rsa -N ''") unless File.exist?("#{File.dirname(__FILE__)}/insecure_keys/key")

if which "vm_stat"
  memfree = `vm_stat | awk '/Pages free/ {print $3 * 4 }'`
elsif File.exist?("/proc/zoneinfo") && File.exist?("/proc/meminfo")
  memfree = `awk -v low=$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}') '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo`
end
puts "Free memory(kb): #{memfree}"

debug = ENV["DEBUG"] || "true"
qat_plugin_mode = ENV.fetch("KRD_QAT_PLUGIN_MODE", nil)
installer_ip = "10.10.16.2"

# Collects IP address exceptions for the Proxy
no_proxy = ENV["NO_PROXY"] || ENV["no_proxy"] || "127.0.0.1,localhost"
nodes.each do |node|
  next unless node.key? "networks"

  node["networks"].each do |network|
    no_proxy += ",#{network['ip']}"
  end
end
(1..254).each do |i|
  no_proxy += ",10.0.2.#{i}"
end
no_proxy += ",#{installer_ip}"

# Discoverying host capabilities
qat_devices = ""
sriov_devices = ""
qemu_version = ""
if which "lspci"
  qat_devices = if qat_plugin_mode == "kernel"
                  `for i in 0434 0435 37c8 6f54 19e2; do lspci -d 8086:$i -m; done|awk '{print $1}'`
                else
                  `for i in 0442 0443 37c9 19e3; do lspci -d 8086:$i -m; done|awk '{print $1}'`
                end
  sriov_devices = `lspci | grep "Ethernet .* Virtual Function"|awk '{print $1}'`
end
qemu_version = `qemu-system-x86_64 --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/'` if which "qemu-system-x86_64"

Vagrant.configure("2") do |config|
  config.vm.provider "libvirt"
  config.vm.provider "virtualbox"

  config.vm.synced_folder "./", "/vagrant"
  config.vm.provider "libvirt" do |v, override|
    override.vm.synced_folder "./", "/vagrant", type: "nfs", nfs_version: ENV.fetch("VAGRANT_NFS_VERSION", 3)
    v.management_network_address = "10.0.2.0/24"
    # Administration - Provides Internet access for all nodes and is
    # used for administration to install software packages
    v.management_network_name = "administration"
    v.random_hostname = true
    v.disk_device = "sda"
  end
  config.ssh.insert_key = false
  config.vm.box_check_update = false

  # Provide a basic configuration
  config.vm.provision "shell", inline: <<-SHELL
    if [ -f /etc/netplan/01-netcfg.yaml ]; then
        sed -i "s/addresses: .*/addresses: [1.1.1.1, 8.8.8.8, 8.8.4.4]/g" /etc/netplan/01-netcfg.yaml
        netplan apply
    fi
    date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"

    if ! command -v curl; then
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            ubuntu|debian)
                apt-get update -qq > /dev/null
                apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
            ;;
        esac
    fi
  SHELL

  if !ENV["http_proxy"].nil? && !ENV["https_proxy"].nil? && Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = ENV["http_proxy"] || ENV["HTTP_PROXY"] || ""
    config.proxy.https    = ENV["https_proxy"] || ENV["HTTPS_PROXY"] || ""
    config.proxy.no_proxy = no_proxy
    config.proxy.enabled = { docker: false }
  end

  config.vm.provider "virtualbox" do |v|
    v.gui = false
    # it will cause the NAT gateway to accept DNS traffic and the gateway will
    # read the query and use the host's operating system APIs to resolve it
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    # https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/network_performance.html
    v.customize ["modifyvm", :id, "--nictype1", "virtio", "--cableconnected1", "on"]
    # Enable nested paging for memory management in hardware
    v.customize ["modifyvm", :id, "--nestedpaging", "on"]
    # Use large pages to reduce Translation Lookaside Buffers usage
    v.customize ["modifyvm", :id, "--largepages", "on"]
    # Use virtual processor identifiers  to accelerate context switching
    v.customize ["modifyvm", :id, "--vtxvpid", "on"]
  end

  nodes.each do |node|
    config.vm.define node["name"] do |nodeconfig|
      nodeconfig.vm.hostname = node["name"]
      if node.key? "networks"
        node["networks"].each do |network|
          nodeconfig.vm.network :private_network, ip: network["ip"], type: :static, libvirt__network_name: network["name"], nic_type: "virtio", virtualbox__intnet: true
        end
      end
      %i[virtualbox libvirt].each do |provider|
        nodeconfig.vm.provider provider do |p, _override|
          p.cpus = node["cpus"]
          p.memory = node["memory"]
        end
      end
      nodeconfig.vm.box = vagrant_boxes[node["os"]["name"]][node["os"]["release"]]["name"]
      nodeconfig.vm.box_version = vagrant_boxes[node["os"]["name"]][node["os"]["release"]]["version"] if vagrant_boxes[node["os"]["name"]][node["os"]["release"]].key? "version"
      nodeconfig.vm.provider "virtualbox" do |v, _override|
        v.customize ["modifyvm", :id, "--nested-hw-virt", "on"] if node["roles"].include?("kube-node")
        if node.key? "storage_controllers"
          node["storage_controllers"].each do |storage_controller|
            # Add VirtualBox storage controllers if they weren't added before
            v.customize ["storagectl", :id, "--name", storage_controller["name"], "--add", storage_controller["type"], "--controller", storage_controller["controller"], "--portcount", "5"] if which("VBoxManage") && (!`VBoxManage showvminfo $(VBoxManage list vms | awk '/#{node["name"]}/{gsub(".*{","");gsub("}.*","");print}') --machinereadable 2>&1 | grep storagecontrollername`.include? storage_controller["name"])
          end
        end
        if node.key? "volumes"
          port = 0
          device = 1
          node["volumes"].each do |volume|
            # Setup user values
            port = volume["port"] if volume.key? "port"
            device = volume["device"] if volume.key? "device"
            controller = "IDE Controller"
            controller = (volume["controller"]).to_s if volume.key? "controller"

            # Storage Controller validations
            raise "#{node['name']} volume uses the main port and device IDs" if port.zero? && device.zero?

            if controller.eql? "IDE Controller"
              raise "#{node['name']} volume uses the port #{port} which is out of range" unless port.between?(0, 1)
              raise "#{node['name']} volume uses the device #{device} which is out of range" unless device.between?(0, 1)
            else
              raise "#{node['name']} volume uses the port #{port} which is out of range" unless port.between?(0, 4)
              raise "#{node['name']} volume uses the device #{device} which is not valid" if device != 0
            end
            volume_file = "#{node['name']}-#{volume['name']}.vdi"
            unless File.exist?(volume_file)
              v.customize ["createmedium", "disk", "--filename", volume_file, "--size",
                           (volume["size"] * 1024)]
            end
            v.customize ["storageattach", :id, "--storagectl", controller, "--port", port, "--type", "hdd",
                         "--medium", volume_file, "--device", device]
            port += 1 unless volume.key? "port"
            device += 1 unless volume.key? "device"
          end
        end
      end
      nodeconfig.vm.provider "libvirt" do |v, _override|
        v.disk_bus = "sata"
        v.nested = true if node["roles"].include?("kube-node")
        v.loader = loader if node["os"] == "clearlinux"
        v.cpu_mode = "host-passthrough"
        if node.key? "volumes"
          node["volumes"].each do |volume|
            v.storage :file, bus: "sata", device: volume["name"], size: volume["size"]
          end
        end
        # Intel Corporation Persistent Memory
        if Gem::Version.new(qemu_version) > Gem::Version.new("2.6.0") && (node.key? "pmem")
          v.qemuargs value: "-machine"
          v.qemuargs value: "pc,nvdimm=on"
          v.qemuargs value: "-m"
          v.qemuargs value: "#{node['pmem']['size']},slots=#{node['pmem']['slots']},maxmem=#{node['pmem']['max_size']}"
          node["pmem"]["vNVDIMMs"].each do |nvdimm|
            v.qemuargs value: "-object"
            v.qemuargs value: "memory-backend-file,id=#{nvdimm['mem_id']},share=#{nvdimm['share']},mem-path=#{nvdimm['path']},size=#{nvdimm['size']}"
            v.qemuargs value: "-device"
            v.qemuargs value: "nvdimm,id=#{nvdimm['id']},memdev=#{nvdimm['mem_id']},label-size=2M"
          end
        end
        # Intel Corporation QuickAssist Technology
        if node.key? "qat_dev"
          node["qat_dev"].each do |dev|
            next unless qat_devices.include? dev.to_s

            bus = dev.split(":")[0]
            slot = dev.split(":")[1].split(".")[0]
            function = dev.split(":")[1].split(".")[1]
            v.pci bus: "0x#{bus}", slot: "0x#{slot}", function: "0x#{function}"
          end
        end
        # Non-Uniform Memory Access (NUMA)
        if node.key? "numa_nodes"
          numa_nodes = []
          node["numa_nodes"].each do |numa_node|
            numa_node["cpus"].strip!
            numa_nodes << { cpus: numa_node["cpus"], memory: (numa_node["memory"]).to_s }
          end
          v.numa_nodes = numa_nodes
        end
        # Single Root I/O Virtualization (SR-IOV)
        if node.key? "sriov_dev"
          node["sriov_dev"].each do |dev|
            next unless sriov_devices.include? dev.to_s

            bus = dev.split(":")[0]
            slot = dev.split(":")[1].split(".")[0]
            function = dev.split(":")[1].split(".")[1]
            v.pci bus: "0x#{bus}", slot: "0x#{slot}", function: "0x#{function}"
          end
        end
      end

      # Setup SSH keys on target nodes
      nodeconfig.vm.provision "shell", inline: <<-SHELL
        mkdir -p /root/.ssh
        cat /vagrant/insecure_keys/key.pub | tee /root/.ssh/authorized_keys
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        sudo sed -i '/^PermitRootLogin no/d' /etc/ssh/sshd_config
      SHELL
      volume_mounts_dict = ""
      if node.key? "volumes"
        node["volumes"].each do |volume|
          volume_mounts_dict += "#{volume['name']}=#{volume['mount']}," if volume.key? "mount"
        end
      end
      # Setup QAT nodes
      nodeconfig.vm.provision "shell", inline: <<-SHELL
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            clear-linux-os)
                mkdir -p /etc/kernel/{cmdline.d,cmdline-removal.d}
                echo "module.sig_unenforce" | sudo tee /etc/kernel/cmdline.d/allow-unsigned-modules.conf
                echo "intel_iommu=igfx_off" | sudo tee /etc/kernel/cmdline-removal.d/disable-iommu.conf
                clr-boot-manager update
                sudo mkdir -p /etc/systemd/resolved.conf.d
                printf "[Resolve]\nDNSSEC=false" | sudo tee /etc/systemd/resolved.conf.d/dnssec.conf
            ;;
            centos)
                curl -fsSL http://bit.ly/install_pkg | PKG=kernel PKG_UPDATE=true bash
                sudo grub2-set-default 0
                grub_cfg="$(sudo readlink -f /etc/grub2.cfg)"
                if dmesg | grep EFI; then
                    grub_cfg="/boot/efi/EFI/centos/grub.cfg"
                fi
                sudo grub2-mkconfig -o "$grub_cfg"
            ;;
        esac
      SHELL
      nodeconfig.vm.provision :reload if node["os"] == "centos"
      nodeconfig.vm.provision "shell", privileged: false do |sh|
        sh.env = {
          KRD_DEBUG: debug.to_s,
          PKG_DEBUG: debug.to_s,
          NODE_SRIOV_NUMVFS: node.fetch("sriov_numvfs", 0),
          NODE_VOLUME: volume_mounts_dict[0...-1].to_s
        }
        sh.inline = <<-SHELL
          set -o xtrace
          cd /vagrant
          cmd="./node.sh"
          if [[ $NODE_VOLUME ]]; then
              cmd+=" -v $NODE_VOLUME"
          fi
          cmd+=" | tee ~/node.log"
          eval $cmd
        SHELL
      end
    end
  end

  config.vm.define :installer, primary: true, autostart: false do |installer|
    installer.vm.hostname = "undercloud"
    installer.vm.box = installer_box["name"]
    installer.vm.box_version = installer_box["version"]
    installer.vm.network :forwarded_port, guest: 9090, host: 9090

    %w[virtualbox libvirt].each do |provider|
      installer.vm.provider provider do |p|
        p.cpus = 1
        p.memory = 1024
      end
    end

    # NOTE: A private network set up is required by NFS. This is due
    # to a limitation of VirtualBox's built-in networking.
    installer.vm.network "private_network", ip: installer_ip, nic_type: "virtio", virtualbox__intnet: true
    installer.vm.provision "shell", privileged: false, inline: <<-SHELL
      cd /vagrant
      sudo mkdir -p /root/.ssh/
      sudo cp insecure_keys/key /root/.ssh/id_rsa
      cp insecure_keys/key ~/.ssh/id_rsa
      sudo chmod 400 /root/.ssh/id_rsa
      chown "$USER" ~/.ssh/id_rsa
      chmod 400 ~/.ssh/id_rsa
    SHELL
    installer.vm.provision "shell", privileged: false do |sh|
      sh.env = {
        KRD_DEBUG: debug.to_s,
        PKG_DEBUG: debug.to_s,
        KRD_ANSIBLE_DEBUG: debug.to_s,
        KRD_MULTUS_ENABLED: ENV.fetch("KRD_MULTUS_ENABLED", nil),
        KRD_QAT_PLUGIN_MODE: qat_plugin_mode.to_s,
        KRD_NETWORK_PLUGIN: ENV.fetch("KRD_NETWORK_PLUGIN", nil),
        KRD_CONTAINER_RUNTIME: ENV.fetch("KRD_CONTAINER_RUNTIME", nil),
        KRD_KUBE_VERSION: ENV.fetch("KRD_KUBE_VERSION", nil),
        KRD_KUBESPRAY_VERSION: ENV.fetch("KRD_KUBESPRAY_VERSION", nil),
        KRD_DOCKER_VERSION: ENV.fetch("KRD_DOCKER_VERSION", nil),
        KRD_CONTAINERD_VERSION: ENV.fetch("KRD_CONTAINERD_VERSION", nil),
        KRD_KATA_CONTAINERS_ENABLED: ENV.fetch("KRD_KATA_CONTAINERS_ENABLED", nil),
        KRD_CRUN_ENABLED: ENV.fetch("KRD_CRUN_ENABLED", nil),
        KRD_YOUKI_ENABLED: ENV.fetch("KRD_YOUKI_ENABLED", nil),
        KRD_METALLB_ENABLED: ENV.fetch("KRD_METALLB_ENABLED", nil),
        KRD_KUBESPRAY_REPO: ENV.fetch("KRD_KUBESPRAY_REPO", nil),
        KRD_REGISTRY_MIRRORS_LIST: "http://#{installer_ip}:5000",
        KRD_INSECURE_REGISTRIES_LIST: "#{installer_ip}:5000",
        KRD_CERT_MANAGER_ENABLED: ENV.fetch("KRD_CERT_MANAGER_ENABLED", nil),
        KRD_INGRESS_NGINX_ENABLED: ENV.fetch("KRD_INGRESS_NGINX_ENABLED", nil),
        KRD_FLANNEL_BACKEND_TYPE: ENV.fetch("KRD_FLANNEL_BACKEND_TYPE", nil),
        KRD_KUBE_PROXY_MODE: ENV.fetch("KRD_KUBE_PROXY_MODE", nil),
        KRD_DASHBOARD_ENABLED: ENV.fetch("KRD_DASHBOARD_ENABLED", nil),
        PKG_KREW_PLUGINS_LIST: ENV.fetch("PKG_KREW_PLUGINS_LIST", nil),
        KRD_DNS_ETCHOSTS_DICT: etchosts_dict.to_s
      }
      sh.inline = <<-SHELL
        # Create .bash_aliases
        echo 'cd /vagrant/' >> /home/vagrant/.bash_aliases
        chown vagrant:vagrant /home/vagrant/.bash_aliases

        # Persists KRD variables
        for krd_var in $(printenv | grep KRD_); do echo "export $krd_var" | sudo tee --append /etc/environment ; done

        cd /vagrant/
        ./krd_command.sh -a install_local_registry -a install_k8s | tee ~/vagrant_init.log
      SHELL
    end
  end
end
