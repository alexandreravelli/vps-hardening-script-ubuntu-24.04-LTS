# 🚀 VPS Hardening Script (Ubuntu 24.04 LTS)

> **Production-Ready Security Suite for Ubuntu 24.04 LTS**
> Secure your VPS in minutes with best practices, automated hardening, and Dokploy deployment.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)
![Security](https://img.shields.io/badge/Security-Hardened-green.svg)

## ✨ Features

### 🎨 **Modern User Experience**
- **📊 Real-time Progress Bar**: Visual progress with percentage and ETA
- **📋 Pre-Installation Summary**: See all steps and time estimates before starting
- **🎯 Post-Installation Dashboard**: Complete status overview with service checks
- **✅ Step-by-Step Validation**: Automatic verification after each critical step
- **🎨 Consistent Visual Design**: Color-coded status, clear hierarchy, professional styling

### 🔐 **Security & Hardening**
- **🖥️ Interactive Menu**: Manage everything from a single dashboard
- **🔐 Secure User**: Creates a sudo user with SSH keys and removes the default `ubuntu` user
- **🛡️ Network Hardening**:
    - **Static IP**: Optional safe configuration with auto-rollback (`netplan try`)
    - **DNS Privacy**: Enforces **Quad9** (DoT) and ignores ISP/DHCP DNS
    - **Firewall**: UFW configured with strict defaults
- **🐳 Docker & Dokploy**: Production-ready Docker setup (log rotation, overlay2) + Dokploy
- **🔒 Post-SSL Security**: Automatically locks down port 3000 after SSL setup
- **📊 Security Audit**: Comprehensive checkup (SSH, AppArmor, Kernel, DNS)
- **🔍 System Integrity Check**: Verify critical binaries haven't been tampered with

## 🚀 Quick Start

### 1. One-Command Installation
Run this on your fresh Ubuntu 24.04 VPS as the default user (ubuntu):

```bash
curl -sSL https://raw.githubusercontent.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/main/install.sh | bash
```

**This will:**
- Create a secure admin user with SSH key authentication
- Copy all scripts to the new user's home directory
- Ask you to test the SSH connection

### 2. Reconnect and Continue Setup
After testing your SSH connection with the new user:

```bash
# Reconnect with your new user
ssh your-new-user@your-server-ip

# Navigate to the scripts directory
cd ~/vps-hardening*

# Run the continuation script (RECOMMENDED)
./continue_setup.sh
```

**The `continue_setup.sh` script will:**
- ✅ Verify you're logged in as the correct user
- ✅ Create a complete system backup automatically
- ✅ Run the full setup (main_setup.sh)
- ✅ Show you the next steps

**Alternative: Use the interactive menu**
```bash
./menu.sh
# Choose option 1: Run Full Setup
```

### 3. What Gets Installed

**Installation includes (~15 minutes):**
- 📋 Pre-installation summary with time estimates
- [████████████░░░░] Modern progress bar with ETA
- ✅ Validation checkpoints after each step
- 🎯 Complete dashboard at the end

**Configuration:**
- Change SSH port to random high port (50000-59999)
- Configure UFW firewall with validation
- Install and configure Docker + Dokploy
- Enable Fail2Ban and automatic security updates
- Configure Quad9 DNS with DoT
- Remove the default ubuntu user
- Create automatic backups

### 4. Post-Installation Dashboard

After installation completes, you'll see:

```
╔═══════════════════════════════════════════════════════════════╗
║                  🎉  INSTALLATION COMPLETE!  🎉              ║
╚═══════════════════════════════════════════════════════════════╝

━━━ Services Status ━━━
  ✓ SSH:      Running on port 53847
  ✓ UFW:      Active (6 rules)
  ✓ Docker:   Running (1 container)
  ✓ Dokploy:  Ready at http://your-ip:3000
  ✓ Fail2Ban: Monitoring SSH

━━━ Quick Start ━━━
  1. Access Dokploy: http://your-ip:3000
  2. Create your admin account
  3. Configure your first domain
  4. After SSL setup: ./post_ssl_setup.sh

━━━ Documentation ━━━
  • Full docs:      cat README.md
  • Health check:   ./system_check.sh
  • Security audit: ./security_audit.sh

✓ Installation completed in 12m 34s
✓ Backup created: /var/backups/vps-hardening/20241119_143022
```

### 5. Troubleshooting

**If scripts directory not found:**
```bash
# List your home directory
ls -la ~

# If scripts are missing, re-clone manually
git clone https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./continue_setup.sh
```

**If you get permission errors:**
```bash
# Make scripts executable
chmod +x ~/vps-hardening*/*.sh

# Or re-run make_executable.sh
cd ~/vps-hardening*
./make_executable.sh
```

**If you need to restore from backup:**
```bash
# List available backups
ls -la /var/backups/vps-hardening/

# Restore SSH config (example)
sudo cp -r /var/backups/vps-hardening/YYYYMMDD_HHMMSS/ssh /etc/
sudo systemctl restart ssh
```

# Navigate to the scripts directory
cd ~/vps-hardening-script-ubuntu-24.04-LTS

# Run the main setup
./main_setup.sh

# OR use the interactive menu
./menu.sh
```

**What happens:**

1. **📋 Installation Plan** - Review all steps and estimated time (~15 minutes)
2. **📊 Progress Tracking** - Real-time progress bar with ETA
3. **✅ Validation** - Automatic checks after each step
4. **🎯 Dashboard** - Complete status overview when finished

**This will configure:**
- Change SSH port to a random high port (50000-59999)
- Configure UFW firewall with strict rules
- Install and configure Docker + Dokploy
- Enable Fail2Ban and automatic security updates
- Remove the default ubuntu user
- Set up Quad9 DNS with DNS-over-TLS

### 2. Reconnect with Your New User
```bash
ssh your-new-user@your-server-ip
```

### 3. Run the Main Setup
```bash
cd ~/vps-hardening-script-ubuntu-24.04-LTS
./main_setup.sh
```

**Or use the interactive menu:**
```bash
cd ~/vps-hardening-script-ubuntu-24.04-LTS
./menu.sh
```

**Or use the quick start script:**
```bash
cd ~/vps-hardening-script-ubuntu-24.04-LTS
./quick_start.sh
```

## 📋 Menu Options

Access the interactive menu with: `./menu.sh`

1.  **🚀 Run Full Setup** - Complete server hardening (recommended for new servers)
    - System update and security tools
    - Firewall and SSH configuration
    - Docker and Dokploy installation
    - Automatic security updates
    - **Includes:** Progress bar, validation checks, and final dashboard

2.  **👤 Create User Only** - Just create a secure admin user
    - SSH key authentication
    - Sudo privileges
    - Password validation

3.  **🌐 Configure Network** - Optional static IP configuration
    - Shows current network status (DHCP/Static)
    - Safe configuration with `netplan try` (auto-rollback)
    - Quad9 DNS enforcement
    - **Note:** Most VPS providers work fine with DHCP

4.  **🔒 Post-SSL Security** - Secure port 3000 after SSL setup
    - Blocks external access to Dokploy port
    - Keeps localhost access for management
    - Persistent iptables rules

5.  **📊 System Health Check** - Verify system status
    - Service status (SSH, Docker, Dokploy, Fail2Ban)
    - Resource usage (CPU, RAM, Disk)
    - Network connectivity
    - DNS configuration

6.  **🐳 Configure Docker** - Optimize Docker settings
    - Log rotation (10MB max, 3 files)
    - Storage driver (overlay2)
    - Swarm-compatible configuration

7.  **🔍 System Integrity Check** - Verify system security
    - Package integrity (debsums)
    - SUID binary check
    - Basic rootkit detection
    - Kernel module verification

8.  **✅ Validate Scripts** - Pre-deployment checks
    - Shellcheck integration
    - Syntax validation
    - Dangerous pattern detection
    - Executable permissions

## 🛡️ Security Details

| Feature | Description | Status |
| :--- | :--- | :---: |
| **SSH** | Port changed (random 50000+), Root login disabled, Keys only | ✅ |
| **Firewall** | UFW enabled. Default Deny Incoming. Ports 80/443/SSH allowed | ✅ |
| **DNS** | **Quad9** enforced via Netplan & systemd-resolved. DHCP DNS ignored | ✅ |
| **Fail2Ban** | Protects SSH against brute-force attacks (24h ban) | ✅ |
| **Updates** | Unattended-upgrades enabled for security patches | ✅ |
| **Docker** | Daemon hardened, log rotation enabled (10MB max, 3 files) | ✅ |
| **Validation** | Automatic checks after each critical step | ✅ |
| **Integrity** | System integrity verification available | ✅ |

## ⚠️ Important Notes

### 🔒 Security
- **SSH Port Change**: Port 22 is disabled after setup. Save your new SSH port!
- **User Deletion**: The default `ubuntu` user is removed for security. Test your new user connection first!
- **Port 3000**: Initially open for Dokploy setup. Run `./post_ssl_setup.sh` after SSL configuration.

### 🌐 Network
- **Static IP**: Optional. Most VPS providers work fine with DHCP.
- **Netplan Safety**: Uses `netplan try` with 120-second auto-rollback if you lose connection.
- **DNS**: Quad9 DNS-over-TLS is enforced, ignoring DHCP/ISP DNS.

### 📊 Monitoring
- **Progress Bar**: Shows real-time progress with ETA during installation
- **Validation**: Automatic checks verify each step completed successfully
- **Dashboard**: Final status overview shows all service states
- **Logs**: Everything logged to `/var/log/vps_setup.log`

### 🔄 Recovery
- **State Management**: Installation can resume from last successful step
- **Rollback**: Automatic rollback on critical errors
- **Emergency Script**: `./emergency_rollback.sh` for disaster recovery

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
