# -*- mode: ruby -*-
# vi: set ft=ruby :

auto = ENV['AUTO_START_SWARM'] || true
gluster = ENV['AUTO_GLUSTERFS'] || true

$registry_mirror_host = nil
$registry_mirror_port = nil
$registry_mirror_ip = nil
if ENV['REGISTRY_MIRROR']
  $registry_mirror_host = ENV['REGISTRY_MIRROR'].split(/:/)[0]
  $registry_mirror_port = ENV['REGISTRY_MIRROR'].split(/:/)[1]
  File.readlines('/etc/hosts').each do |line|
    if m = line.match(/^(\S+)\s+.*\b#{$registry_mirror_host}\b.*/)
      $registry_mirror_ip = m[1]
    end
  end
end
$registry_mirror_cert = ENV['REGISTRY_MIRROR_CERT']

# Increase numworkers if you want more than 3 nodes
numworkers = 4

# VirtualBox settings
# Increase vmmemory if you want more than 512mb memory in the vm's
vmmemory = 2048
# Increase numcpu if you want more cpu's per vm
numcpu = 1

instances = []

(1..numworkers).each do |n| 
  instances.push({:name => "worker#{n}", :ip => "192.168.10.#{n+2}"})
end

manager_ip = "192.168.10.2"

File.open("./hosts", 'w') { |file| 
  instances.each do |i|
    file.write("#{i[:ip]} #{i[:name]} #{i[:name]}\n")
  end
}

http_proxy = ""
# Proxy configuration
if ENV['http_proxy']
	http_proxy = ENV['http_proxy']
	https_proxy = ENV['https_proxy']
end

no_proxy = "localhost,127.0.0.1,#{manager_ip}"
instances.each do |instance|
    no_proxy += ",#{instance[:ip]}"
end

# Vagrant version requirement
Vagrant.require_version ">= 2.2.0"

def configure_registry_mirror(i)
  if $registry_mirror_host
    if $registry_mirror_cert
      i.vm.provision "shell", privileged: true, inline: "echo '** Add registry mirror cert';
        mkdir -p /etc/docker/certs.d/#{$registry_mirror_host}:#{$registry_mirror_port}
        cp /vagrant/#{$registry_mirror_cert} /etc/docker/certs.d/#{$registry_mirror_host}:#{$registry_mirror_port}/ca.crt
      "
    end
    if $registry_mirror_ip
      i.vm.provision "shell", privileged: true, inline: "echo '** Configure registry mirror in /etc/hosts'; fgrep -q #{$registry_mirror_ip} /etc/hosts || echo \"#{$registry_mirror_ip} #{$registry_mirror_host} #{$registry_mirror_host}\" >> /etc/hosts"
    end
    i.vm.provision "shell", privileged: true, inline: "echo '** Configure registry mirror'; echo '{\"registry-mirrors\":[\"https://#{$registry_mirror_host}:#{$registry_mirror_port}\"]}' >/etc/docker/daemon.json; systemctl reload docker"
  else
    i.vm.provision "shell", privileged: true, inline: "echo '** Removing registry mirror'; rm /etc/docker/daemon.json; systemctl reload docker"
  end
end

Vagrant.configure("2") do |config|
    config.vagrant.plugins = ["vagrant-proxyconf", "vagrant-cachier", "vagrant-vbguest"]

    if Vagrant.has_plugin?("vagrant-cachier")
      config.cache.scope = :box
    end

    config.vbguest.auto_update = true
    config.vm.provider "virtualbox" do |v|
     	v.memory = vmmemory
      v.cpus = numcpu
      v.linked_clone = true
    end
    
    config.vm.define "manager" do |i|
      i.vm.box = "ubuntu/bionic64"
      i.vm.hostname = "manager"
      i.vm.network "private_network", ip: "#{manager_ip}"
      i.vm.network "forwarded_port", guest:2375, host:2375
      i.vm.network "forwarded_port", guest:2376, host:2376
      i.vm.network "forwarded_port", guest:8080, host:8080
      i.vm.network "forwarded_port", guest:8081, host:8081
      i.vm.network "forwarded_port", guest:8082, host:8082
      i.vm.network "forwarded_port", guest:8083, host:8083
      i.vm.network "forwarded_port", guest:8084, host:8084
      i.vm.network "forwarded_port", guest:8085, host:8085
      i.vm.synced_folder "synced/manager", "/data"
      # Proxy
      if not http_proxy.to_s.strip.empty?
        i.proxy.http     = http_proxy
        i.proxy.https    = https_proxy
        i.proxy.no_proxy = no_proxy
      end
      i.vm.provision "shell", path: "./provision.sh", privileged: true
      if File.file?("./hosts") 
        i.vm.provision "file", source: "hosts", destination: "/tmp/hosts"
        i.vm.provision "shell", inline: "cat /tmp/hosts >> /etc/hosts", privileged: true
      end 
      configure_registry_mirror(i)
      if auto
        i.vm.provision "shell", inline: "
          if docker node ls | fgrep manager >/dev/null
          then
            echo 'manager detect as part of docker swarn. Init swarm skiped'
          else
            echo '** Swarn init #{manager_ip}'
            docker swarm init --advertise-addr #{manager_ip}
          fi
        "
        i.vm.provision "shell", inline: "echo '** Generating join-token for workers'; docker swarm join-token -q worker > /vagrant/token"
        if gluster
          # Generate ssh keys in order to allow execution of remote commands between workers
          i.vm.provision "shell", inline: "
            if [ -f /vagrant/id_rsa_provision ]
            then
              echo 'SSH keys exists on /vagrant/id_rsa_provision. Use them'
            else
              ssh-keygen -t rsa -b 4096 -C provision -f /vagrant/id_rsa_provision -q -N ''
            fi
          "
          i.vm.provision "shell", inline: "cat /vagrant/id_rsa_provision.pub >> ~vagrant/.ssh/authorized_keys"
          i.vm.provision "shell", inline: "echo '** Installing volume plugins for glusterfs';
            docker plugin ls | grep -q glusterfs || (
            docker plugin install --alias glusterfs trajano/glusterfs-volume-plugin --grant-all-permissions --disable
            docker plugin set glusterfs SERVERS=#{instances.collect {|i| i[:name]}.join(',')}
            docker plugin enable glusterfs )
          "
        end
      end
    end 

  gluster_node_paths=""
  instances.each_with_index do |instance, idx|
    config.vm.define instance[:name] do |i|
      i.vm.box = "ubuntu/bionic64"
      i.vm.hostname = instance[:name]
      i.vm.network "private_network", ip: "#{instance[:ip]}"
      # Proxy
      if not http_proxy.to_s.strip.empty?
        i.proxy.http     = http_proxy
        i.proxy.https    = https_proxy
        i.proxy.no_proxy = no_proxy
      end
      i.vm.provision "shell", path: "./provision.sh", privileged: true
      if File.file?("./hosts") 
        i.vm.provision "file", source: "hosts", destination: "/tmp/hosts"
        i.vm.provision "shell", inline: "cat /tmp/hosts >> /etc/hosts", privileged: true
      end 
      configure_registry_mirror(i)
      if auto
        # Gluster volumes
        if gluster
          # sudo systemctl start glusterfs-server
          i.vm.provision "shell", inline: "echo '** Creating gluster paths'; sudo mkdir -p /gluster/data /swarm/volumes"
          i.vm.provision "shell", inline: "echo '** Adding SSH pub key'; cat /vagrant/id_rsa_provision.pub >> ~vagrant/.ssh/authorized_keys"
          gluster_node_paths="#{gluster_node_paths} #{instance[:ip]}:/gluster/data"
          # We create shared filesystem only in first node
          if instance[:name].equal?(instances.last[:name])
            # Gluster peer nodes
            instances.each do |j|
              i.vm.provision "shell", inline: "echo '** Gluster peer probe over #{j[:name]}'; sudo gluster peer probe #{j[:name]}"
            end
            i.vm.provision "shell", inline: "
              if sudo gluster volume list | fgrep swarm-vols > /dev/null
              then
                echo '** swarn-vols exists. Ignoring gluster volume creation'
              else
                echo '** Creating swarm-vols'
                sudo gluster volume create swarm-vols replica #{idx + 1} #{gluster_node_paths} force
                echo '** Setting properties for swarm-vols'
                sudo gluster volume set swarm-vols auth.allow 127.0.0.1
                echo '** Starting swarm-vols volume'
                sudo gluster volume start swarm-vols
              fi
            "
            # Access throug ssh to all nodes in order to mount paths
            instances.each do |j|
              i.vm.provision "shell", inline: "
                echo '** Mounting swarm-vols in remote #{j[:name]}'
                eval `ssh-agent -s`
                ssh-add /vagrant/id_rsa_provision
                ssh -o StrictHostKeyChecking=no vagrant@#{j[:name]} \
                  'mountpoint -q /swarm/volumes || sudo mount.glusterfs localhost:/swarm-vols /swarm/volumes'
              "
            end
          end
          i.vm.provision "shell", inline: "echo '** Installing volume plugins for glusterfs';
            docker plugin ls | grep -q glusterfs || (
            docker plugin install --alias glusterfs trajano/glusterfs-volume-plugin --grant-all-permissions --disable
            docker plugin set glusterfs SERVERS=#{instances.collect {|i| i[:name]}.join(',')}
            docker plugin enable glusterfs )
          "
        end
        i.vm.provision "shell", inline: "
          echo '** Joining node to swarm (checking #{instance[:name]} remotely on #{manager_ip})'
          eval `ssh-agent -s`
          ssh-add /vagrant/id_rsa_provision
          ssh -o StrictHostKeyChecking=no vagrant@#{manager_ip} 'docker node ls' | fgrep '#{instance[:name]}' > /dev/null \
          || docker swarm join --advertise-addr #{instance[:ip]} --listen-addr #{instance[:ip]}:2377 --token `cat /vagrant/token` #{manager_ip}:2377
        "
      end
    end 
  end
end
