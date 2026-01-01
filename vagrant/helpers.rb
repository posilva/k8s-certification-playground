module VagrantHelpers

  def self.install_control_plane(name, host_ip, vc, cc)

    host_ip = "#{cc.hostonly_net_ip_prefix}#{host_ip}"
    hostname = "k8s-cp-#{name}"
    vm_name = "simple-#{hostname}"

    vc.vm.define vm_name do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = vm_name
        vb.memory = cc.vm_ram 
        vb.cpus = cc.vm_cpus
      end

      node.vm.network "private_network", 
        ip: host_ip,
        netmask: cc.hostonly_net_mask,
        name: cc.hostonly_net_name

      node.vm.hostname = hostname

      node.vm.provision "shell", path: "../scripts/00-common.sh", args: [host_ip, cc.vm_user, cc.vm_password]
      node.vm.provision "shell", path: "scripts/10-control-plane.sh", args: [host_ip]
      node.vm.provision "shell", path: "../scripts/99-common-post.sh"
    end 
  end 


  def self.install_worker_node(name, host_ip, vc, cc)
    host_ip = "#{cc.hostonly_net_ip_prefix}#{host_ip}"
    hostname = "k8s-w-#{name}"
    vm_name = "simple-#{hostname}"

    vc.vm.define vm_name do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = "simple-#{hostname}"
        vb.memory = cc.vm_ram 
        vb.cpus = cc.vm_cpus
      end

      node.vm.network "private_network", 
        ip: host_ip,
        netmask: cc.hostonly_net_mask,
        name: cc.hostonly_net_name

      node.vm.hostname = hostname

      node.vm.provision "shell", path: "../scripts/00-common.sh", args: [host_ip, cc.vm_user, cc.vm_password]
      node.vm.provision "shell", path: "scripts/20-worker.sh"
      node.vm.provision "shell", path: "..//scripts/99-common-post.sh"
    end 
 
  end 
end 
