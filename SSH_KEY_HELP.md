# 🔑 How to Get Your SSH Public Key

## What is an SSH Public Key?

An SSH public key is a cryptographic key that allows you to securely connect to servers without using a password. It's like a digital signature that proves your identity.

## Finding Your SSH Public Key

### On Linux / macOS

Open a terminal and run:

```bash
# For Ed25519 keys (recommended, modern)
cat ~/.ssh/id_ed25519.pub

# For RSA keys (older, but still common)
cat ~/.ssh/id_rsa.pub
```

### On Windows

#### Using PowerShell:
```powershell
# For Ed25519 keys
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub

# For RSA keys
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
```

#### Using Command Prompt:
```cmd
# For Ed25519 keys
type %USERPROFILE%\.ssh\id_ed25519.pub

# For RSA keys
type %USERPROFILE%\.ssh\id_rsa.pub
```

## What Does It Look Like?

Your SSH public key will look something like this:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJl3dIeudNqd0DMSH3YmOqF0ZXXXXXXXXXXXXXXXXXXx user@hostname
```

or

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8... (very long string) ...== user@hostname
```

## Don't Have an SSH Key?

If you get an error like "No such file or directory", you need to generate one first:

### Generate a New SSH Key

```bash
# Recommended: Ed25519 (modern, secure, fast)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Alternative: RSA (widely compatible)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

**During generation:**
1. Press Enter to accept the default file location
2. Enter a passphrase (optional but recommended)
3. Press Enter again to confirm

**After generation:**
```bash
# Display your new public key
cat ~/.ssh/id_ed25519.pub
```

## Important Notes

⚠️ **NEVER share your PRIVATE key** (the file without `.pub`)
- ✅ Share: `id_ed25519.pub` or `id_rsa.pub` (PUBLIC key)
- ❌ Never share: `id_ed25519` or `id_rsa` (PRIVATE key)

## Copy to Clipboard

### Linux (with xclip):
```bash
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
```

### macOS:
```bash
cat ~/.ssh/id_ed25519.pub | pbcopy
```

### Windows (PowerShell):
```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
```

## Troubleshooting

### "Permission denied" error
Your SSH keys might have wrong permissions:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

### Multiple keys
If you have multiple SSH keys, you can specify which one to use:
```bash
ssh -i ~/.ssh/specific_key user@server
```

---

**Need more help?** Check the [GitHub SSH documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
