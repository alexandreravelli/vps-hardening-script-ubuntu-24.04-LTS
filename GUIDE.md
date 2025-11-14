# 🚀 Quick Installation Guide

This guide will help you set up a secure Ubuntu 24.04 VPS with Dokploy in minutes.

## Prerequisites

- Ubuntu 24.04 LTS server
- Root or sudo access
- SSH access to your server
- GitHub account (for SSH key authentication)

## Installation Steps

### 1. Prepare Your SSH Key (Local Machine)

```bash
# On your LOCAL machine, get your SSH public key
cat ~/.ssh/id_ed25519.pub
# or
cat ~/.ssh/id_rsa.pub

# Copy the entire output - you'll need it in step 4
```

### 2. Connect to Your Server

```bash
ssh ubuntu@your-server-ip
```

### 3. Generate SSH Key for GitHub

```bash
ssh-keygen -t ed25519 -C "vps@dokploy"
# Press Enter 3 times to accept defaults

# Display your public key
cat ~/.ssh/id_ed25519.pub
```

### 4. Add SSH Key to GitHub

1. Copy the output from the previous command
2. Go to: https://github.com/settings/keys
3. Click "New SSH key"
4. Paste your key and save

### 5. Clone and Install

```bash
git clone git@github.com:alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
cd vps-hardening-script-ubuntu-24.04-LTS
chmod +x *.sh
./install.sh
```

### 6. Follow the Prompts

The installer will ask you to:
- Choose a username (default: prod-dokploy)
- Paste your SSH public key (from step 1)

Then it will:
- Create the secure user
- Configure SSH access
- Grant sudo privileges

### 7. Reconnect with New User

```bash
exit
ssh <your_username>@your-server-ip
cd ubuntu-2404-production-deploy
./main_setup.sh
```

### 7. Access Dokploy

Open in browser: `http://your-server-ip:3000`

### 8. Configure SSL

1. Add your domain in Dokploy
2. Configure SSL certificate
3. Run security script:

```bash
./post_ssl_setup.sh
```

## Verification

```bash
./system_check.sh
```

## Troubleshooting

### Lost SSH Port?

```bash
cat /tmp/ssh_port_info.txt
```

### Dokploy Not Accessible?

```bash
sudo docker ps
curl http://localhost:3000
```

### Need Help?

Check the full [README.md](README.md) for detailed documentation.

## Next Steps

- Configure your applications in Dokploy
- Set up automatic backups
- Configure monitoring
- Add your domains

---

**Need more help?** Open an issue on GitHub!
