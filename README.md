# Rackmill Ubuntu Setup Script

Rackmill is a robust, operator-friendly Bash script for preparing Ubuntu systems for deployment, imaging, or template creation. It enforces canonical APT sources, configures system settings, and securely cleans sensitive data, with interactive prompts and clear logging throughout.

## Features
- **Canonical APT Sources Enforcement:**
  - Supports both classic (`sources.list`) and deb822 (`ubuntu.sources`) formats.
  - Audits and guides manual correction of non-standard sources.
- **System Configuration:**
  - Sets hostname, locale, and timezone.
  - Regenerates SSH host keys for security.
- **Cleanup Actions:**
  - Identifies and removes sensitive files (SSH keys, shell history, machine IDs, etc.)
  - Operator must confirm all irreversible actions interactively.
- **Backups:**
  - Automatically backs up critical files before changes.
- **Logging:**
  - Uses `section()` and `step()` for clear, color-coded output.
  - All actions and errors are visible to the operator.


# Usage

As the Operator, observe the script as it runs and respond to any errors or prompts during execution.

While the script runs, follow the interactive prompts to review and confirm each step. Manual approval is required, and intervention may be necessary.

## Quick Start

1. Download and run the script directly.

```bash
clear; cd ~
wget https://github.com/adambraimbridge/rackmill.sh/raw/refs/heads/main/rackmill.sh -O rackmill.sh
chmod +x rackmill.sh
sudo ./rackmill.sh
```

## Manual Setup (If Quick Start is not possible)

1. Copy the entire script content from the project file to your clipboard.

The script will guide you through each step with interactive prompts. Manual intervention may be required for some actions.
2. Open terminal and type `nano rackmill.sh` to create/open the file.
3. In nano, press:
    `alt+\` (go to start)
    `ctrl+6` (set marker)
    `alt+/` (go to end)
    `ctrl+k` (paste)
4. Save and exit nano:
    `ctrl+x` (exit)
    `y` (confirm save)
    `enter` (confirm filename)
5. In terminal, make it executable:
    `chmod +x rackmill.sh`
6. Run it:
    `clear; ./rackmill.sh`

## Intended Use
- Preparing Ubuntu VMs for imaging or template deployment
- Ensuring a clean, secure baseline for new systems
- Operator-driven environments where transparency and control are required

## Notes
- Supports Ubuntu 14.04 (Trusty) and newer, including deb822 sources for 23.10+
- No automatic changes to APT sources—operator must manually edit if needed
- All cleanup actions are irreversible and require explicit confirmation

## License
MIT License
