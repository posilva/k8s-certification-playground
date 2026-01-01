module Cluster
  class Config
    attr_reader :vm_ram, 
      :vm_cpus, 
      :vm_user, 
      :vm_password,
      :hostonly_net_ip_prefix,
      :hostonly_net_name,
      :hostonly_net_mask,
      :hostonly_net_id

    def initialize(config)
      globals = config.fetch("global", {})

      @vm_user = globals.fetch("vm_user", "vagrant")
      @vm_password = globals.fetch("vm_password", "vagrant")

      @vm_ram = globals.fetch("vm_ram", 2048)
      @vm_cpus = globals.fetch("vm_cpus", 2)

      @hostonly_net_ip_prefix = globals.fetch("hostonly_net_ip_prefix", "10.50.0")
      @hostonly_net_name = globals.fetch("hostonly_net_name", "vboxnet0")
      @hostonly_net_mask = globals.fetch("hostonly_net_mask", "255.255.255.0")
      @hostonly_net_id = globals.fetch("hostonly_net_id", '16c44191-4ed6-4ebe-9130-9f65087e6bf0')
    end 

    def self.from_yaml_file(filepath)
      return Config.new(YAML.safe_load(File.read(filepath), aliases: true))
    end 
  end 
  
end 
