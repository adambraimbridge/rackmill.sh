# Rackmill Quick Reference - Debian Support

## Quick Version Check

```bash
# What OS and version am I running?
cat /etc/os-release | grep -E "^(ID=|VERSION_ID=|VERSION_CODENAME=)"
```

## Expected Canonical Files by OS/Version

### Ubuntu
| Version Range | Canonical File | Format |
|---------------|----------------|--------|
| 14.04 - 23.04 | `/etc/apt/sources.list` | Classic |
| 23.10+ | `/etc/apt/sources.list.d/ubuntu.sources` | DEB822 |

### Debian
| Version Range | Canonical File | Format |
|---------------|----------------|--------|
| 9 - 11 | `/etc/apt/sources.list` | Classic |
| 12+ | `/etc/apt/sources.list.d/debian.sources` | DEB822 |

## Repository URLs

### Ubuntu
```
Main: http://archive.ubuntu.com/ubuntu
Security: http://security.ubuntu.com/ubuntu
```

### Debian (Current releases: 11+)
```
Main: http://deb.debian.org/debian
Security: http://security.debian.org/debian-security
```

### Debian (Archived releases: 9-10)
```
Main: http://archive.debian.org/debian
Security: http://archive.debian.org/debian-security
Note: No signed Release files (APT warnings expected)
```

## Components

### Ubuntu
- main restricted universe multiverse

### Debian
- **9-11:** main contrib non-free
- **12+:** main contrib non-free non-free-firmware

## Systemd Detection

| OS | Version | Init System |
|----|---------|-------------|
| Ubuntu | < 15.04 | Upstart |
| Ubuntu | ≥ 15.04 | systemd |
| Debian | < 8 | SysV Init |
| Debian | ≥ 8 | systemd |

## Example Canonical Sources

### Debian 9 (Stretch) - Archived, Classic Format
```
deb http://archive.debian.org/debian stretch main contrib non-free
deb http://archive.debian.org/debian stretch-backports main contrib non-free
deb http://archive.debian.org/debian-security stretch/updates main contrib non-free
```
Note: Uses old security suite naming (`stretch/updates` instead of `stretch-security`)

### Debian 11 (Bullseye) - Classic Format
```
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
```

### Debian 12 (Bookworm) - DEB822 Format
```
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates bookworm-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

### Ubuntu 22.04 (Jammy) - Classic Format
```
deb https://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb https://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
```

### Ubuntu 24.04 (Noble) - DEB822 Format
```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

## Troubleshooting

### Script fails with "Unsupported OS detected"
- Only Ubuntu and Debian are supported
- Check: `cat /etc/os-release | grep "^ID="`

### Script fails with version not supported
- **Ubuntu:** Minimum 14.04 (Trusty)
- **Debian:** Minimum 9 (Stretch)
- Check: `cat /etc/os-release | grep "^VERSION_ID="`

### Can't find codename
- The script tries multiple methods to extract the codename
- Check: `cat /etc/os-release | grep -E "CODENAME"`
- Manual fix: Ensure VERSION field has format like "11 (bullseye)"

### Wrong repository URLs detected
- Verify OS_TYPE is correctly set
- Check: Run setup() function and observe console output
- The script will display detected OS during execution

### Journal setup skipped
- **Expected on:** Ubuntu 14.04, Debian < 8 (no systemd)
- **Should run on:** Ubuntu 15.04+, Debian 8+

## Testing Commands

```bash
# Syntax check (no execution)
bash -n /home/adam/Rackmill/rackmill.sh

# Show what would be generated for current system
bash -c 'source /home/adam/Rackmill/rackmill.sh && setup && canonical_sources'

# Check if using DEB822 or classic format
if [ -f /etc/apt/sources.list.d/ubuntu.sources ] || [ -f /etc/apt/sources.list.d/debian.sources ]; then
    echo "Using DEB822 format"
else
    echo "Using classic format"
fi
```

## Global Variables Set by setup()

- `OS_TYPE` - "ubuntu" or "debian"
- `VERSION_ID` - Full version (e.g., "11", "22.04")
- `VERSION_MAJOR` - Major version only (e.g., "11", "22")
- `CODENAME` - Release codename (e.g., "bullseye", "jammy")

## Common Issues

### Debian 9-10 Archived Releases
These versions are archived and use archive.debian.org. The script will:
- Display a warning (⚠️) but continue
- Use archive.debian.org instead of deb.debian.org
- Show APT warnings about expired GPG signatures (expected, archive repos have expired keys)
- **Automatically add `--allow-unauthenticated`** to apt-get commands
- Not block execution - allows template creation for legacy requirements
- Use old security suite format (`stretch/updates` instead of `stretch-security`)

### Mixed source files
If non-canonical .list or .sources files exist in `/etc/apt/sources.list.d/`:
- Script will list them
- Ask operator to confirm before proceeding
- Operator can type 'y' to continue or anything else to exit

### Manual intervention required
If APT sources don't match canonical:
- Script creates a backup
- Displays expected canonical content
- Exits and asks operator to manually edit
- Re-run script after manual edits
