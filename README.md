# Secure VPS Configuration with Dokploy

![Version](https://img.shields.io/badge/version-2.2.0-blue)
![Status](https://img.shields.io/badge/status-production--ready-green)
![Ubuntu](https://img.shields.io/badge/ubuntu-24.04%20LTS-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## 📋 Overview

Automated scripts to configure an OVH VPS server with Dokploy and advanced security hardening.

**🚀 Quick Start:** See [GUIDE.md](GUIDE.md) for simple installation steps!  
**🔑 Need help with SSH keys?** See [SSH_KEY_HELP.md](SSH_KEY_HELP.md)  
**📦 Repository:** https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS

## 🚀 Installation Procedure

#### Step 1: Prepare Your SSH Key
```bash
# On your LOCAL machine, get your SSH public key
cat ~/.ssh/id_ed25519.pub
# or
cat ~/.ssh/id_rsa.pub

# Copy the entire output (starts with ssh-ed25519 or ssh-rsa)
```

#### Step 2: Setup SSH Key on VPS (for GitHub access)
```bash
# As ubuntu user, generate SSH key for GitHub
ssh-keygen -t ed25519 -C "vps@dokploy"
# Press Enter 3 times (accept defaults)

# Display public key
cat ~/.ssh/id_ed25519.pub
# Copy the entire output
```

#### Step 3: Add SSH Key to GitHub
1. Go to: https://github.com/settings/keys
2. Click **"New SSH key"**
3. Title: `VPS Dokploy`
4. Paste your public key
5. Click **"Add SSH key"**

#### Step 4: Clone and Install
```bash
# Clone repository with SSH
git clone git@github.com:alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./install.sh
```

**During installation:**
- You will be asked to choose a username (default: prod-dokploy)
- You will need to paste your SSH public key (from Step 1)

#### Step 5: Reconnect and Setup
```bash
# Exit current session
exit

# Reconnect with your new user
ssh <your_username>@<your_ip>

# Clone repository again (for prod-dokploy user)
git clone git@github.com:alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./main_setup.sh
```

**Note:** The setup will change your SSH port to a random port (50000-59999). Save this port!

#### Step 5: Configure Dokploy
1. Access: `http://<your_ip>:3000`
2. Create admin account
3. Add your domain
4. Configure SSL certificate

#### Step 6: Secure Port 3000 (After SSL)
```bash
# Run post-SSL security script
./post_ssl_setup.sh
```

#### Step 7: Reconnect with New SSH Port
```bash
# Exit current session
exit

# Reconnect with new port (check /tmp/ssh_port_info.txt for port number)
ssh prod-dokploy@<your_ip> -p <new_port>

# Navigate to project directory
cd ubuntu-2404-production-deploy

# Verify installation
./system_check.sh
```

---

### 📋 Quick Reference

**SSH Port Location:**
```bash
cat /tmp/ssh_port_info.txt
```

**Connection Command:**
```bash
cat /tmp/ssh_connection_command.txt
```

**System Verification:**
```bash
./system_check.sh
```

## 🔧 Available Scripts

### Installation Scripts
| Script | Description |
|--------|-------------|
| `install.sh` | **NEW** - One-command installer |
| `quick_start.sh` | **NEW** - Quick start after user creation |
| `create_user.sh` | Secure user creation |
| `main_setup.sh` | Complete system configuration |
| `post_ssl_setup.sh` | Post-SSL security hardening |

### Maintenance & Troubleshooting
| Script | Description |
|--------|-------------|
| `system_check.sh` | **ENHANCED** - System health verification with colors |
| `configure_docker.sh` | **NEW** - Configure Docker daemon with log rotation and network cleanup |

### Configuration
| File | Description |
|------|-------------|
| `.env.example` | **NEW** - Configuration template |

## ✨ Production-Ready Features

### 🔐 Security
- **Random SSH port** (50000-59999) with persistence after reboot
- **SSH socket permanently masked** (no port override)
- **UFW firewall** for SSH protection only
- **Prerequisites validation** before installation
- **Robust error handling** with automatic rollback
- **Detailed logging** with rotation
- **Secure removal** of default user at end of setup

### 🐳 Docker Best Practices
- **Log rotation** (max 10MB per file, 3 files max)
- **Optimized storage driver** (overlay2)
- **Native port management** (no UFW interference)
- **Health checks** before deployment
- **Network cleanup** (automatic pruning of unused networks)
- **Custom address pools** (172.17.0.0/12 with /24 subnets)

### 🛡️ Error Management
- Automatic rollback function
- Configuration validation before application
- Service status verification with retries
- Critical configuration backups with timestamps

### 📊 Monitoring & Verification
- System health check script
- **btop** - Modern system resource monitor
- Centralized logging with rotation
- Service status verification
- Dokploy HTTP response check

### 🔧 Key Features
- **One-command installation**: Quick and easy setup
- **Beautiful terminal UI**: Professional ASCII art banners and color-coded output
- **Custom username support**: Choose your own username during installation
- **Manual SSH key configuration**: You provide your own SSH public key
- **Enhanced error handling**: Detailed error messages with troubleshooting suggestions
- **Simple architecture**: UFW for SSH, Docker for containers
- **Dokploy verification**: HTTP response validation
- **Docker daemon**: Production-ready configuration with log rotation
- **System monitoring**: btop installed for beautiful resource monitoring
- **Automatic backup**: Before each critical modification
- **Port 3000 security**: Blocked after SSL setup (iptables persistent)
- **Configuration template**: .env.example for easy customization

## 🔍 System Verification

```bash
# Enhanced system health check (with colors and detailed diagnostics)
./system_check.sh
```

The enhanced system check now includes:
- ✅ Color-coded output for better readability
- ✅ Public IP detection
- ✅ SSH connectivity test
- ✅ Dokploy HTTP response validation
- ✅ Disk and memory usage warnings
- ✅ iptables rules verification
- ✅ Issue and warning counters
- ✅ Exit codes (0 = success, 1 = issues found)

## 📝 Important Information

### Configuration Files
- **SSH Port**: Saved in `/tmp/ssh_port_info.txt`
- **Docker daemon**: `/etc/docker/daemon.json` (with log rotation)
- **iptables rules**: Saved with `iptables-persistent`

### Logs
- **Setup logs**: `/var/log/vps_setup.log`
- **Docker logs**: Rotated automatically (max 30MB per container)

### Backups
- **SSH config**: `/etc/ssh/sshd_config.bak`
- **Docker daemon**: `/etc/docker/daemon.json.bak.YYYYMMDD_HHMMSS`
- **UFW rules**: `/etc/ufw/after.rules.bak.YYYYMMDD_HHMMSS`

### Services
- **SSH Socket**: Permanently masked (no port override)
- **SSH Service**: Enabled to start automatically on boot
- **Docker**: Manages container ports natively
- **Fail2Ban**: Monitors SSH on custom port

## 🆘 Emergency Procedures

### Lost SSH Access
1. Use OVH console
2. Manually restore: `sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && sudo systemctl restart ssh`

### Dokploy Not Accessible
```bash
# Check system status
./system_check.sh

# Verify Docker is running
sudo docker ps

# Test local access
curl -I http://localhost:3000
```

### Complete Rollback
Scripts include automatic rollback function in case of errors during installation.

## 🔧 Maintenance

### Regular Verification
```bash
# Complete system check
./system_check.sh

# System resource monitor (interactive)
btop

# Configure Docker daemon (log rotation, storage, network cleanup)
./configure_docker.sh

# Firewall status
sudo ufw status numbered

# Fail2Ban status
sudo fail2ban-client status sshd

# Docker status
sudo docker ps
```

### Log Monitoring
```bash
# Setup logs
tail -f /var/log/vps_setup.log

# Docker-UFW rules logs
tail -f /var/log/docker-ufw-rules.log

# Docker logs (auto-rotated)
docker logs -f dokploy

# SSH logs
sudo journalctl -u ssh.service -f

# Fail2Ban logs
sudo journalctl -u fail2ban -f
```

### Verify Docker Ports
```bash
# Check open ports
sudo ss -tlnp | grep docker

# Test Dokploy access
curl -I http://localhost:3000

# Check iptables rules (after SSL setup)
sudo iptables -L DOCKER-USER -n -v
```



## 🎯 Architecture

### Firewall Strategy
- **UFW**: Manages SSH port only (simple and reliable)
- **Docker**: Manages container ports natively (3000, 80, 443)
- **iptables**: Blocks port 3000 after SSL setup (persistent)

### Why This Approach?
- ✅ **Simplicity**: No complex UFW-Docker integration
- ✅ **Reliability**: Docker ports work out of the box
- ✅ **Maintainability**: Less moving parts, fewer issues
- ✅ **Security**: Port 3000 blocked after SSL configuration

## 🎯 Tested & Verified

- ✅ Ubuntu 24.04 LTS
- ✅ Multiple reboots
- ✅ SSH persistence
- ✅ Dokploy accessibility
- ✅ Log rotation

---

**Status**: ✅ Production Ready  
**Last Update**: 2025-10-04  
**Tested on**: Ubuntu 24.04 LTS