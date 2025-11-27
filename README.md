# VPS Hardening Script (Ubuntu 24.04 LTS)

Secure your VPS and install Dokploy in one command.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/main/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

## What It Does

The script runs 9 steps interactively:

1. **Create admin user** - New sudo user with password
2. **Configure SSH key** - Paste your public key
3. **Update system** - apt update/upgrade
4. **Install security tools** - UFW + Fail2Ban
5. **Configure firewall** - Opens only necessary ports
6. **Harden SSH** - Custom port, disable root login
7. **Install Docker** - With log rotation
8. **Install Dokploy** - Self-hosted deployment platform
9. **Remove old user** - Optional cleanup

## Security Features

| Feature | Description |
|---------|-------------|
| SSH | Random port (50000-60000), root disabled, key-only auth |
| Firewall | UFW with deny-by-default, only SSH/80/443/3000 open |
| Fail2Ban | Protects SSH (3 attempts, 1h ban) |
| Rate limiting | UFW limits SSH to 6 connections/30s per IP |
| Password policy | Min 12 chars, mixed case, numbers, symbols required |
| Audit logging | Tracks sudo, auth, SSH, user/group changes |
| Auto-updates | Security patches applied daily via unattended-upgrades |
| Timezone | UTC (consistent logs) |
| Swap | 2GB swap file (prevents OOM kills) |
| Docker | Log rotation (10MB max, 3 files) |

## Safety Measures

- Password auth stays enabled until you confirm SSH key works
- Port 22 stays open until you confirm custom port works
- Won't auto-delete user if you're logged in as that user
- Fail2Ban configured for custom SSH port

## After Installation

```
SSH:     ssh your-user@your-ip -p YOUR_PORT
Dokploy: http://your-ip:3000
```

### Post-SSL Security

After configuring SSL in Dokploy, block external access to port 3000:

```bash
sudo iptables -I DOCKER-USER -p tcp --dport 3000 -j DROP
sudo iptables -I DOCKER-USER -i lo -p tcp --dport 3000 -j ACCEPT
```

## Requirements

- Fresh Ubuntu 24.04 LTS VPS
- User with sudo privileges
- SSH public key ready

## License

MIT
