# 🔒 VPS Security Hardening + Dokploy

> **Production-ready automated security setup for Ubuntu 24.04 LTS VPS with Dokploy deployment platform**

[![Version](https://img.shields.io/badge/version-3.0.0-blue)](https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/releases)
[![Ubuntu](https://img.shields.io/badge/ubuntu-24.04%20LTS-orange)](https://ubuntu.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/status-production--ready-brightgreen)](https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS)

---

## 🎯 What This Does

Transforms a fresh Ubuntu VPS into a **secure, production-ready server** with:
- ✅ Hardened SSH configuration (custom port, key-only auth)
- ✅ Firewall (UFW) + intrusion prevention (Fail2Ban)
- ✅ Secure DNS with Quad9 (encrypted, malware blocking)
- ✅ Docker with production settings
- ✅ Dokploy deployment platform
- ✅ Automatic security updates
- ✅ Complete rollback capability

**Time to setup:** ~10 minutes | **Difficulty:** Beginner-friendly

---

## ⚡ Quick Start

### Prerequisites
- Fresh Ubuntu 24.04 LTS VPS
- SSH access as `ubuntu` user
- Your SSH public key ready

### Installation

**1. Get your SSH key** (on your local machine):
```bash
cat ~/.ssh/id_ed25519.pub
# Copy the output
```

**2. Connect to your VPS**:
```bash
ssh ubuntu@YOUR_VPS_IP
```

**3. Download and run installer**:
```bash
git clone https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./install.sh
```

**4. Connect with your new user and run the main setup**:
```bash
# SSH with the new user created in step 3
ssh your_new_user@YOUR_VPS_IP

# Then run:
git clone https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./main_setup.sh
```
Follow the interactive prompts:
- System update and security tools installation
- Custom SSH port configuration (50000-59999)
- Docker and Dokploy installation
- SSH connection test before finalizing
- Confirm when SSH works on the new port

**5. Access Dokploy**:
```
http://YOUR_VPS_IP:3000
```

**6. After SSL setup**:
```bash
./post_ssl_setup.sh  # Blocks port 3000 externally
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [**GUIDE.md**](GUIDE.md) | Step-by-step installation guide |
| [**TROUBLESHOOTING.md**](TROUBLESHOOTING.md) | Common issues and solutions |
| [**CHANGELOG.md**](CHANGELOG.md) | Version history and changes |
| [**SSH_KEY_HELP.md**](SSH_KEY_HELP.md) | How to generate SSH keys |

---

## 🛠️ Scripts Overview

### Core Scripts
```bash
./install.sh              # One-command installer
./create_user.sh          # Create secure admin user
./main_setup.sh           # Main security setup
./post_ssl_setup.sh       # Lock down port 3000 after SSL
```

### Maintenance
```bash
./system_check.sh         # Health check with diagnostics
./security_audit.sh       # Comprehensive security scan
./configure_docker.sh     # Update Docker configuration
./emergency_rollback.sh   # Restore to safe state
```

---

## ✨ Key Features

### 🔐 Security First
- **Custom SSH port** (50000-59999) with dual-port safety during migration
- **Interactive testing** before removing default user
- **UFW firewall** configured before Docker (prevents bypass)
- **Fail2Ban** monitors SSH attempts (24h ban)
- **Root login disabled**
- **SSH key-only authentication**
- **Automatic security updates**
- **Secure DNS** with Quad9 (encrypted, malware blocking)

### 🐳 Docker Production-Ready
- Log rotation (10MB max, 3 files)
- Overlay2 storage driver
- Swarm-compatible configuration
- Health checks before deployment
- Network cleanup automation

### 🌐 Secure DNS (Quad9)
- **DNS over TLS** - All queries encrypted
- **DNSSEC** - Prevents DNS spoofing
- **Malware blocking** - Automatic protection
- **ECS enabled** - Optimized CDN performance
- **IPv4 + IPv6** - Dual-stack ready
- **8 DNS servers** - Maximum redundancy

### 🛡️ Bulletproof Error Handling
- **State management** - Resume from any step
- **Automatic rollback** on errors
- **Emergency recovery** script included
- **Timestamped backups** of all configs
- **Comprehensive logging**

### 📊 Monitoring
- Color-coded health checks
- Security audit tool
- Service status verification
- Disk/memory warnings
- iptables rules validation

---

## 🎯 What Makes This Different

| Feature | This Project | Typical Scripts |
|---------|--------------|-----------------|
| SSH Safety | ✅ Dual-port + testing | ❌ Direct change |
| Rollback | ✅ Full state restore | ❌ Manual only |
| Firewall | ✅ Before Docker | ❌ After (bypassed) |
| Idempotent | ✅ Resume from any step | ❌ Start over |
| Testing | ✅ Interactive verification | ❌ Hope it works |
| Recovery | ✅ Emergency script | ❌ Console access only |

---

## 🚨 Emergency Recovery

**Lost SSH access?**
```bash
# Via OVH/provider console:
cd vps-hardening-script-ubuntu-24.04-LTS
sudo bash emergency_rollback.sh
```

This restores:
- SSH to port 22
- Disables firewall
- Restores all backups
- Re-enables services

---

## 📋 System Requirements

- **OS**: Ubuntu 24.04 LTS
- **RAM**: 1GB minimum (2GB recommended)
- **Disk**: 3GB free space
- **Network**: Public IP address
- **Access**: Root or sudo privileges

---

## 🔍 Verification

After installation, verify everything:

```bash
# Quick health check
./system_check.sh

# Comprehensive security audit
./security_audit.sh

# Check specific services
sudo systemctl status ssh docker fail2ban
sudo ufw status
sudo docker ps
```

---

## 🎓 Architecture

```
┌─────────────────────────────────────────┐
│         Internet Traffic                │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼──────┐
        │     UFW     │  ← SSH only (custom port)
        │  Firewall   │
        └──────┬──────┘
               │
        ┌──────▼──────┐
        │   Docker    │  ← Manages own ports
        │   Engine    │     (80, 443, 3000*)
        └──────┬──────┘
               │
        ┌──────▼──────┐
        │   Dokploy   │  ← Deployment platform
        │  Container  │
        └─────────────┘

* Port 3000 blocked externally after SSL setup
```

### 🌐 DNS Configuration

**Quad9 with DNS over TLS (DoT)**

| Type | Servers | Features |
|------|---------|----------|
| **Primary** | 9.9.9.11, 149.112.112.11<br>2620:fe::11, 2620:fe::fe:11 | ECS enabled (CDN optimized) |
| **Fallback** | 9.9.9.9, 149.112.112.112<br>2620:fe::fe, 2620:fe::9 | Standard (more privacy) |

**All DNS servers include:**
- ✅ Malware/phishing blocking
- ✅ DNSSEC validation
- ✅ TLS encryption
- ✅ IPv4 + IPv6 support

**Why this works:**
- UFW handles SSH (simple, reliable)
- Docker handles containers (native, fast)
- iptables blocks 3000 after SSL (secure)
- No conflicts, no complexity

---

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

**Found a bug?** [Open an issue](https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/issues)

**Have a feature idea?** [Start a discussion](https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/discussions)

---

## 📊 Project Stats

- **Scripts**: 11 production-ready bash scripts
- **Documentation**: 10 comprehensive guides
- **Security Fixes**: 15+ critical issues resolved
- **New Features**: 30+ enhancements in v3.0
- **Lines of Code**: ~2,500 added in latest version
- **Test Coverage**: All scripts syntax-validated

---

## 🏆 Tested On

- ✅ OVH VPS
- ✅ DigitalOcean Droplets
- ✅ Hetzner Cloud
- ✅ AWS EC2 (Ubuntu 24.04)
- ✅ Multiple reboots verified
- ✅ SSH persistence confirmed
- ✅ Dokploy accessibility validated

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

<div align="center">

**⭐ Star this repo if it helped you!**

Made with ❤️ for the DevOps community

</div>
