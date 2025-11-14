# Release Notes - Version 2.2.0

**Release Date:** November 14, 2025

## 🎉 What's New

### 1. Custom Username Support
- **No more hardcoded usernames!** You can now choose your own username during installation
- Default remains `prod-dokploy` if you prefer to keep it simple
- Username is automatically saved and used across all scripts

### 2. Enhanced SSH Key Security
- **You provide your own SSH public key** during user creation
- No more automatic copying from the ubuntu user
- More secure and gives you full control over access
- Clear instructions and validation

### 3. System Monitoring with btop
- **Automatic installation of btop** - a modern, beautiful system monitor
- Real-time CPU, RAM, disk, and network monitoring
- Interactive and colorful interface
- Just type `btop` after installation!

### 4. Comprehensive SSH Key Guide
- New **SSH_KEY_HELP.md** file with detailed instructions
- How to find your SSH public key on Linux, macOS, and Windows
- How to generate a new SSH key if you don't have one
- Troubleshooting tips and best practices

## 🔄 What Changed

### Installation Process
**Before (v2.1.0):**
```bash
./install.sh
# Creates user "prod-dokploy" automatically
# Copies SSH key from ubuntu user
```

**Now (v2.2.0):**
```bash
./install.sh
# Prompts: "Enter the name for the new user (default: prod-dokploy):"
# Prompts: "SSH Public Key:" (you paste your key)
# More control, more secure!
```

### Script Updates
All scripts now dynamically read the username from `/tmp/new_user_name.txt`:
- `main_setup.sh`
- `post_ssl_setup.sh`
- `system_check.sh`
- `quick_start.sh`

### Documentation
- Updated README.md with new SSH key workflow
- Updated GUIDE.md with step-by-step SSH key instructions
- Added SSH_KEY_HELP.md for detailed SSH key guidance

## 📋 Migration Guide

### Upgrading from v2.1.0

If you're already using v2.1.0, you don't need to do anything! Your existing installation will continue to work.

For new installations, just follow the updated guide:

1. **Prepare your SSH public key** (see SSH_KEY_HELP.md)
2. Run `./install.sh`
3. Choose your username (or press Enter for default)
4. Paste your SSH public key when prompted
5. Continue with the rest of the installation

## 🔧 Technical Details

### New Files
- `SSH_KEY_HELP.md` - Comprehensive SSH key guide
- `CHANGELOG.md` - Version history
- `RELEASE_NOTES_v2.2.0.md` - This file

### Modified Files
- `create_user.sh` - Username prompt and SSH key input
- `main_setup.sh` - Dynamic username reading, btop installation
- `post_ssl_setup.sh` - Dynamic username reading
- `system_check.sh` - Dynamic username reading
- `quick_start.sh` - Dynamic username reading
- `install.sh` - Updated prompts and instructions
- `README.md` - Updated documentation and version badge
- `GUIDE.md` - Updated installation steps

### New Features in Scripts
```bash
# Username is saved for other scripts
echo "$NEW_USER" | sudo tee /tmp/new_user_name.txt > /dev/null

# Scripts read the username dynamically
if [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
else
    NEW_USER="prod-dokploy"  # Fallback
fi

# btop installation
sudo snap install btop
```

## 🎯 Benefits

### Security
✅ **Better control**: You decide which SSH key to use  
✅ **No automatic copying**: Explicit is better than implicit  
✅ **Audit trail**: Clear record of which key was added

### Flexibility
✅ **Custom usernames**: Use your organization's naming convention  
✅ **Multiple deployments**: Different usernames for different servers  
✅ **Team-friendly**: Each team member can use their own key

### User Experience
✅ **Clear prompts**: Know exactly what's happening  
✅ **Better documentation**: SSH_KEY_HELP.md covers all scenarios  
✅ **Modern tools**: btop for beautiful system monitoring

## 🐛 Bug Fixes

- None in this release (feature release)

## 📊 Compatibility

- ✅ Ubuntu 24.04 LTS
- ✅ Backward compatible with v2.1.0 installations
- ✅ All existing features preserved

## 🔮 Coming Soon

- Configuration file support (.env)
- Multiple SSH key support
- Automated backup configuration
- Email notifications
- Monitoring dashboard

## 📝 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## 🙏 Feedback

Found a bug? Have a suggestion? Open an issue on GitHub!

---

**Enjoy the new features!** 🚀
