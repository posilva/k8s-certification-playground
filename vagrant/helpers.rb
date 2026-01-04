module VagrantHelpers

  def self.install_node(type, host_ip_sufix, vc, cc, scripts_builder)

    host_ip = "#{cc.hostonly_net_ip_prefix}#{host_ip_sufix}"
    hostname = "k8s-#{type}-#{host_ip_sufix}"
    vm_name = "simple-#{hostname}"

    scripts = scripts_builder.call(host_ip, cc)

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

      scripts.each do |script|
        node.vm.provision "shell", 
          path: script[:path], 
          args: script[:args] || []
      end
    end 
    {
      ip: host_ip,
      hostname: hostname,
      vm_name: vm_name,
      type: type
    }
  end
end 

