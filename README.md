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
   - Debug: If no IP, check Hyper-V Manager > VM Settings > Network Adapter > Virtual switch is set correctly. Restart VM: `vagrant reload`.

4. **Verify DMS Stack Inside VM**
   - SSH: `vagrant ssh`.
   - Run `docker ps` (all services up).
   - Verify LDAP users: `docker compose exec openldap ldapsearch -x -H ldap://localhost:1389 -b "ou=users,dc=dms,dc=local" "(objectClass=inetOrgPerson)" uid cn`
   - JBPM dashboard: `https://workflow.agenticone.in/business-central` (or your configured JBPM hostname).
   - Verification: Logs: `docker compose logs -f traefik`. Access Traefik dashboard: `https://demo.agenticone.in` (or your configured Traefik hostname).
   - Debug: If compose fails, check /vagrant/docker-compose.yml paths. Regenerate certs if SSL issues. Restart: `docker compose down && docker compose up -d`.

5. **Access Services from Host**
   - For production, ensure your DNS records for `demo.agenticone.in`, `sso.agenticone.in`, and `workflow.agenticone.in` point to the public IP of your server.
   - For local testing, you can add these hostnames to your local hosts file (e.g., `C:\Windows\System32\drivers\etc\hosts`) pointing to the VM's IP.
   - Verification: Browser: `https://workflow.agenticone.in/business-central`. The certificate should be valid from Let's Encrypt.
   - Debug: Firewall: Allow inbound on VM (ufw allow if enabled). Ensure Traefik labels correct.

### JBPM shows a 404 Error

A 404 error from the JBPM URL (`/business-central/`) usually means the web application failed to deploy.
1.  **Check JBPM Logs:** Run `docker compose logs jbpm` and look for errors during startup, especially related to `Keycloak` or database connections.
2.  **Check Deployment Status:** SSH into the VM and `exec` into the container to check the deployment markers.
    `docker compose exec jbpm ls -l /opt/jboss/wildfly/standalone/deployments/`
    You should see `business-central.war.deployed`. If you see `business-central.war.failed`, the logs from step 1 will contain the reason.

6. **Security Note: Traefik Dashboard Password**
   The `docker-compose.yml` file contains a default password hash for the Traefik dashboard. For any real deployment, you should generate your own. You can do this by installing `apache2-utils` (`sudo apt-get install apache2-utils`) and running:
   `echo $(htpasswd -nb admin your_new_password) | sed -e s/\\$/\\$\\$/g`
   Replace the `users` value in the Traefik labels with the output of this command.

7. **Teardown**
   - `vagrant halt` to stop, `vagrant destroy` to delete VM.
   - Verification: Hyper-V Manager shows VM off/deleted.
   - Debug: If destroy fails, manually delete in Hyper-V Manager.

## Troubleshooting

### "Connection Refused" or "Unable to Connect" from Host

This error means your request is not reaching the Traefik service. Follow these steps to diagnose:

1.  **Check Traefik Container:** SSH into the VM (`vagrant ssh`) and run `docker ps`. Ensure the `traefik` container is in a `running` state.
2.  **Check Listening Ports:** Inside the VM, verify that Docker is listening on ports 80 and 443.
    ```bash
    sudo ss -tlpn | grep -E ':80|:443'
    ```
    You should see output showing a `docker-proxy` process for both ports. If not, the Traefik container failed to start or bind the ports. Check its logs with `docker logs traefik`.
3.  **Check VM Firewall:** The `provision.sh` script configures `ufw`. Verify its status with `sudo ufw status`. It should show ports 22, 80, and 443 as `ALLOW`.
4.  **Check Host Firewall:** On your Windows host, ensure your firewall (e.g., Windows Defender Firewall) allows inbound traffic on TCP ports 80 and 443 for the network profile used by your Hyper-V virtual switch (often "Public"). You can test the connection with `Test-NetConnection -ComputerName <VM_IP> -Port 443`.

## Additional Tips
- Customize: Edit Vagrantfile for more CPUs/RAM. Add port forwards if needed (config.vm.network "forwarded_port", ...).
- Scripts: provision.sh runs once; for reprovision: `vagrant provision`.
- Security: Change `.env` passwords. For prod, use proper certs and generate your own Traefik password.
- Issues: Check Vagrant logs in .vagrant/ folder. Hyper-V errors: Event Viewer > Applications and Services Logs > Microsoft > Windows > Hyper-V-VMMS.
- Updates: For newer Ubuntu/Docker, update box version in Vagrantfile.

If problems, provide error logs from `vagrant up`.
