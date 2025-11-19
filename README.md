# 🚀 VPS Hardening Script (Ubuntu 24.04 LTS)

> **Production-Ready Security Suite for Ubuntu 24.04 LTS**
> Secure your VPS in minutes with best practices, automated hardening, and Dokploy deployment.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)
![Security](https://img.shields.io/badge/Security-Hardened-green.svg)

## ✨ Features

- **🖥️ Interactive Menu**: Manage everything from a single dashboard.
- **🔐 Secure User**: Creates a sudo user with SSH keys and removes the default `ubuntu` user.
- **🛡️ Network Hardening**:
    - **Static IP**: Safe configuration with auto-rollback (`netplan try`).
    - **DNS Privacy**: Enforces **Quad9** (DoT) and ignores ISP/DHCP DNS.
    - **Firewall**: UFW configured with strict defaults.
- **🐳 Docker & Dokploy**: Production-ready Docker setup (log rotation, overlay2) + Dokploy.
- **🔒 Post-SSL Security**: Automatically locks down port 3000 after SSL setup.
- **📊 Security Audit**: Comprehensive checkup (SSH, AppArmor, Kernel, DNS).

## 🚀 Quick Start

### 1. One-Command Installation
Run this on your fresh Ubuntu 24.04 VPS:

```bash
curl -sSL https://raw.githubusercontent.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/main/install.sh | bash
```

### 2. Using the Menu
After installation, launch the main menu to configure your server:

```bash
cd ~/vps-hardening
sudo ./menu.sh
```

## 📋 Menu Options

1.  **🚀 Run Full Setup**: The standard path for a new server. Handles user creation, firewall, and Docker.
2.  **👤 Create User Only**: Just want a secure user? Use this.
3.  **🌐 Configure Network**: Set a **Static IP** and enforce **Quad9 DNS**. Safe to use remotely!
4.  **🔒 Post-SSL Security**: Run this *after* you've set up your domains in Dokploy to block external access to port 3000.
5.  **📊 System Health Check**: Run a deep security audit of your system.
6.  **🐳 Configure Docker**: Optimize Docker daemon settings.
7.  **🔍 System Integrity Check**: Verify critical binaries haven't been tampered with.
8.  **✅ Validate Scripts**: Check all scripts for common issues before running.

## 🛡️ Security Details

| Feature | Description |
| :--- | :--- |
| **SSH** | Port changed (random 50000+), Root login disabled, Keys only. |
| **Firewall** | UFW enabled. Default Deny Incoming. Ports 80/443/SSH allowed. |
| **DNS** | **Quad9** enforced via Netplan & systemd-resolved. DHCP DNS ignored. |
| **Fail2Ban** | Protects SSH against brute-force attacks. |
| **Updates** | Unattended-upgrades enabled for security patches. |
| **Docker** | Daemon hardened, log rotation enabled (10MB max). |

## ⚠️ Important Notes

- **Static IP**: The script uses `netplan try`. If you lose connection, **WAIT 120 SECONDS**. It will automatically revert changes.
- **Port 3000**: Initially open for Dokploy setup. Use option #4 to close it once SSL is active.
- **User Deletion**: The script aggressively removes the default `ubuntu` user for security. Ensure you test your new user connection first!

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
