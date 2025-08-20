Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.box_version = "4.3.12"  # Hyper-V compatible version
  config.vm.hostname = "dms-vm"
  config.vm.synced_folder ".", "/vagrant", type: "smb"  # Use SMB for Windows host

  # Provider: Hyper-V
  config.vm.provider "hyperv" do |hv|
    hv.vmname = "DMS-VM"
    hv.cpus = 4
    hv.memory = 8192
    hv.maxmemory = 16384
    hv.enable_virtualization_extensions = true  # For nested virt/Docker
    hv.linked_clone = true
    hv.vm_integration_services = {
      guest_service_interface: true,
      heartbeat: true,
      key_value_pair_exchange: true,
      shutdown: true,
      time_synchronization: true,
      vss: true
    }
  end

  # Network: Bridged to existing switch
  config.vm.network "public_network", bridge: "ExtSwitchWSLBridge"

  # Provisioning: Install Docker, setup, and run compose
  config.vm.provision "shell", path: "provision.sh"
end
