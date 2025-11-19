# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 3.0.x   | :white_check_mark: |
| 2.x     | :x:                |
| < 2.0   | :x:                |

## Security Features

### Authentication & Access Control
- **SSH Key-Only Authentication**: Password authentication disabled by default
- **Non-Standard SSH Port**: Random port between 50000-59999
- **Root Login Disabled**: Root access completely blocked via SSH
- **Default User Removal**: Ubuntu default user removed after setup

### Network Security
- **UFW Firewall**: Configured before Docker installation to prevent bypass
- **Fail2Ban**: Active monitoring and banning of brute-force attempts
- **Secure DNS**: Quad9 with DNS-over-TLS and DNSSEC
- **Port 3000 Hardening**: Dokploy port blocked externally after SSL setup

### System Hardening
- **Automatic Security Updates**: Unattended-upgrades for security patches
- **AppArmor**: Mandatory Access Control enabled
- **Docker Security**: Log rotation, no live-restore (Swarm-compatible)
- **Minimal Attack Surface**: Only essential ports open (SSH, 80, 443)

## Reporting a Vulnerability

**Please DO NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via:
1. GitHub Security Advisories (preferred)
2. Email to the maintainer (see GitHub profile)

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline
- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 7 days
  - Medium: 30 days
  - Low: 90 days

## Security Best Practices

### Before Running Scripts
1. **Review the code**: Never run scripts blindly
2. **Check integrity**: Verify checksums if available
3. **Test in VM**: Always test on disposable infrastructure first
4. **Backup**: Take snapshots before making changes

### After Installation
1. **Change default values**: Don't use example usernames
2. **Enable 2FA**: For Dokploy admin panel
3. **Regular updates**: Run `sudo apt update && sudo apt upgrade`
4. **Monitor logs**: Check `/var/log/vps_setup.log` regularly
5. **Run audits**: Use `./security_audit.sh` monthly

### SSH Key Management
- **Use Ed25519**: Preferred over RSA
  ```bash
  ssh-keygen -t ed25519 -C "your_email@example.com"
  ```
- **Protect private keys**: Never share or commit
- **Use passphrases**: Always protect keys with strong passphrases
- **Rotate keys**: Change keys every 6-12 months

### Password Policy
- **Minimum 8 characters**: Enforced by scripts
- **Use password manager**: Generate strong random passwords
- **No reuse**: Unique password per service
- **Regular rotation**: Change every 90 days

## Known Limitations

### Current Scope
- **Ubuntu 24.04 LTS only**: Not tested on other distributions
- **Fresh installations**: Not designed for existing configured systems
- **Single-server**: Not for multi-server orchestration

### Not Included
- **DDoS Protection**: Use CloudFlare or similar
- **WAF**: Web Application Firewall not included
- **IDS/IPS**: Intrusion Detection/Prevention not configured
- **Log aggregation**: No centralized logging
- **Backup automation**: Manual backup required

## Security Checklist

After installation, verify:

- [ ] SSH accessible only on custom port
- [ ] Root login disabled
- [ ] Password authentication disabled
- [ ] UFW firewall active
- [ ] Fail2Ban running
- [ ] Automatic updates enabled
- [ ] Default user removed
- [ ] Port 3000 blocked externally (after SSL)
- [ ] Docker logs rotating
- [ ] System integrity verified

Run: `./security_audit.sh` to automate these checks.

## Incident Response

If you suspect a compromise:

1. **Isolate**: Disconnect from network if possible
2. **Assess**: Run `./security_audit.sh` and `./check_system_integrity.sh`
3. **Preserve**: Don't delete logs
4. **Restore**: Use `./emergency_rollback.sh` if needed
5. **Investigate**: Check `/var/log/auth.log` and `/var/log/syslog`
6. **Report**: If vulnerability in scripts, report to maintainers

## Compliance

This project follows:
- **CIS Benchmarks**: Ubuntu 24.04 LTS guidelines
- **OWASP**: Web application security principles
- **NIST**: Cybersecurity framework basics

## Updates

Security updates are released as:
- **Patch versions** (3.0.x): Security fixes
- **Minor versions** (3.x.0): New security features
- **Major versions** (x.0.0): Breaking changes

Subscribe to GitHub releases for notifications.

---

**Last Updated**: 2024-11-19
**Version**: 3.0.0
