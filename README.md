# Vagrant Setup for DMS Project on Hyper-V

This automates creating a Ubuntu VM on Hyper-V, bridged to 'ExtSwitchWSLBridge', and running the DMS Docker stack inside it.

## Prerequisites
- Windows 11 Pro with Hyper-V enabled (Settings > Apps > Optional features > Hyper-V).
- Vagrant installed[](https://www.vagrantup.com/downloads).
- Install Hyper-V provider: `vagrant plugin install vagrant-hyperv`.
- Existing Hyper-V switch 'ExtSwitchWSLBridge' (create if needed via Hyper-V Manager > Virtual Switch Manager > External).
- DMS project files in this directory (copy from previous setup: docker-compose.yml, .env, traefik/, openldap/, keycloak/).
- PowerShell as admin if issues arise.

## Installation Steps

1. **Prepare Directory**
   - Create `dms-vagrant` folder, add Vagrantfile, provision.sh, and DMS files.
   - Make provision.sh executable: In Git Bash or WSL: `chmod +x provision.sh`.
   - Verification: Run `dir` (Windows) or `ls` to confirm files. Check Vagrantfile syntax: `vagrant validate`.
   - Debug: If validation fails, check indentation (use spaces, not tabs). Ensure box exists or Vagrant will download it.

2. **Start VM**
   - Run as admin (if Hyper-V needs it): Open PowerShell as Administrator, cd to directory, `vagrant up --provider=hyperv`.
   - This downloads the box, creates VM, bridges network, provisions Docker, generates certs, and runs `docker compose up -d`.
   - Verification: In Hyper-V Manager, see 'DMS-VM' running. Run `vagrant status` (should be 'running'). SSH in: `vagrant ssh`, then `docker ps` (shows 6 containers).
   - Debug: If fails, check `vagrant up` output. Common issues:
     - Switch not found: Verify name with `Get-VMSwitch` in PowerShell.
     - Network issues: Ensure host has internet; restart Hyper-V service.
     - Provision errors: SSH in (`vagrant ssh`), check /var/log/syslog or run provision.sh manually.
     - If box download fails: Manually download from Vagrant Cloud and add: `vagrant box add generic/ubuntu2204 --provider=hyperv`.

3. **Verify Network Bridging**
   - In VM: `vagrant ssh`, then `ip addr show eth1` (or similar; shows IP from bridged network).
   - On host: Ping the VM's IP.
   - Verification: VM has external IP (not 10.x.x.x NAT). Access Keycloak: https://<vm-ip> (or via localhost if port forwarded, but bridged allows direct).
   - Debug: If no IP, check Hyper-V Manager > VM Settings > Network Adapter > Virtual switch set to 'ExtSwitchWSLBridge'. Restart VM: `vagrant reload`.

4. **Verify DMS Stack Inside VM**
   - SSH: `vagrant ssh`.
   - Run `docker ps` (all services up).
   - Follow previous README steps 5-10 for individual service verification (e.g., ldapsearch, Keycloak UI at https://<vm-ip>, etc.).
   - JBPM dashboard: https://<vm-ip>/business-central (via Traefik).
   - Verification: Logs: `docker compose logs -f`. Access Traefik dashboard: https://<vm-ip>/dashboard/.
   - Debug: If compose fails, check /vagrant/docker-compose.yml paths. Regenerate certs if SSL issues. Restart: `docker compose down && docker compose up -d`.

5. **Access Services from Host**
   - Use the VM's bridged IP (find with `vagrant ssh -c "ip addr show"`).
   - Add to hosts file if needed: e.g., C:\Windows\System32\drivers\etc\hosts – `<vm-ip> keycloak.localhost jbpm.localhost`.
   - Verification: Browser: https://jbpm.localhost/business-central (accept self-signed cert).
   - Debug: Firewall: Allow inbound on VM (ufw allow if enabled). Ensure Traefik labels correct.

6. **Teardown**
   - `vagrant halt` to stop, `vagrant destroy` to delete VM.
   - Verification: Hyper-V Manager shows VM off/deleted.
   - Debug: If destroy fails, manually delete in Hyper-V Manager.

## Additional Tips
- Customize: Edit Vagrantfile for more CPUs/RAM. Add port forwards if needed (config.vm.network "forwarded_port", ...).
- Scripts: provision.sh runs once; for reprovision: `vagrant provision`.
- Security: Change .env passwords. For prod, use proper certs.
- Issues: Check Vagrant logs in .vagrant/ folder. Hyper-V errors: Event Viewer > Applications and Services Logs > Microsoft > Windows > Hyper-V-VMMS.
- Updates: For newer Ubuntu/Docker, update box version in Vagrantfile.

If problems, provide error logs from `vagrant up`.
