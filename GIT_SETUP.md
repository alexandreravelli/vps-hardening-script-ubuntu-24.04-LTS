# 🚀 Git Setup Instructions

## After creating the repository on GitHub, run these commands:

### 1. Initialize Git Repository

```bash
git init
```

### 2. Add All Files

```bash
git add .
```

### 3. Create Initial Commit

```bash
git commit -m "Initial commit: Ubuntu 24.04 production deployment scripts

- Automated VPS setup with Dokploy
- Advanced security hardening
- Random SSH port configuration
- UFW firewall and Fail2Ban
- Docker with log rotation
- One-command installation
- Comprehensive system health checks
- Production-ready configuration"
```

### 4. Set Main Branch

```bash
git branch -M main
```

### 5. Add Remote Origin

```bash
git remote add origin git@github.com:alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git
```

### 6. Push to GitHub

```bash
git push -u origin main
```

## Verify

```bash
git remote -v
git status
```

## Future Updates

```bash
# After making changes
git add .
git commit -m "Description of changes"
git push
```

## Create a Release (Optional)

After pushing, create a release on GitHub:

1. Go to: https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/releases/new
2. Tag version: `v2.1.0`
3. Release title: `v2.1.0 - Production Ready`
4. Description: Copy from CHANGELOG.md
5. Publish release

---

**Note:** Make sure you have SSH access configured with GitHub before running these commands.
