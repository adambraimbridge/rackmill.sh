# Rackmill Project Notes

## Q1 — Should the hostname always be set to `rackmill`?

**A1:** Yes — this script intentionally sets the hostname to `rackmill` for branding and
template consistency across Rackmill VM images.

## Q2 — Is hardcoding Ubuntu Xenial (16.04) sources intentional, or should other versions be supported?

**A2:** Yes — other versions should be supported.
Rackmill (overall) supports the following releases:

### Ubuntu Releases

- **Interim Releases**
  - Ubuntu 25.04 (Plucky Puffin)

- **LTS Releases**
  - Ubuntu 24.04.3 LTS (Noble Numbat)
  - Ubuntu 22.04.5 LTS (Jammy Jellyfish)

- **Extended Security Maintenance (ESM)**
  - Ubuntu 20.04.6 LTS (Focal Fossa)
  - Ubuntu 18.04.6 LTS (Bionic Beaver)
  - Ubuntu 16.04.7 LTS (Xenial Xerus)
  - Ubuntu 14.04.6 LTS (Trusty Tahr)

### Debian Releases

- **Current Releases**
  - Debian 13 (Trixie) - Current stable
  - Debian 12 (Bookworm) - Oldstable
  - Debian 11 (Bullseye) - Oldoldstable, LTS until 2031

- **Archived Releases (Uses archive.debian.org)**
  - Debian 10 (Buster) - No security updates, archive.debian.org only
  - Debian 9 (Stretch) - No security updates, archive.debian.org only
  - Note: APT warnings about missing Release files are expected for archived releases

## Q3 — Are further customizations (e.g., SSH keys, branding, user accounts) required, or is this only for baseline OS setup?

**A3:** The script should perform industry-standard tidying for template images. Example actions:

- Clear interactive shell history (for example, remove or `~/.bash_history`).
- Remove existing SSH host keys (for example, `/etc/ssh/ssh_host_*`) and remove any preseeded
  `authorized_keys` so guests receive fresh keys on first boot.
- Clean up machine identifiers and udev persistent rules where applicable
  (for example, `/etc/machine-id`, `/etc/udev/rules.d/70-persistent-net.rules`).
- Delete log files (in e.g. `/var/log`) and remove temporary files
  (for example, `/tmp/*`) to remove sensitive data.
- Remove GPG keyrings and trust databases (for example, `~/.gnupg` for all users, `/root/.gnupg`).
- Remove Vim editor history files (for example, `~/.viminfo` for all users, `/root/.viminfo`).

## Security cleanup — additional recommendations

The following items are recommended for template hardening. They focus on removing sensitive data, avoiding accidental network/device carryover, and improving reproducibility.

Notes on safety

- Prefer idempotent, reversible actions where possible (truncate vs delete). Document irreversible removals in the PR.
 - Decision: Do not add CLI flags to `rackmill.sh` (interactive confirmation only for destructive actions).
 - Add verification steps (small tests) that confirm machine-id is empty, SSH host keys are absent, and cloud-init will run on first boot.

Operational assumption

This script is intended to be executed interactively by a human who has SSH'd into the machine and will be watching the run closely. Operators will respond to any errors or prompts during execution. Because of that, avoid hidden magic or broad error suppression across the script; prefer explicit, local handling for commands that are expected to sometimes fail. In short: make failures visible to the operator (within reason), and keep the script predictable and debuggable.

## Decisions 
### Support multi-release sources by auto-detecting the Ubuntu release
- For multi-release handling, prefer auto-detecting the current Ubuntu release on the running image
  (for example `lsb_release -r` or parsing `/etc/os-release`) and select the matching `sources.list`.
  Avoid requiring a manual `--release` unless there's a deliberate need to override detection.

### Do not surpress the upgrade banner.
- The upgrade banner should not be suppressed. It is bettter to leave original behavior intact and let
  users see upgrade prompts. 

### Do not add CLI flags to `rackmill.sh`.
- The script must avoid adding `--release`, `--dry-run`, or any other flags. Behavior should be
  auto-detected (release) and interactive where confirmation is required (cleanup). 

## Checklist
- [x] Implement cleanup steps in `rackmill.sh` with safe defaults (interactive confirmation at end)
- [x] Support multi-release sources by auto-detecting the Ubuntu release
- [x] Add Debian 9-15 support with OS type detection
- [ ] Test on actual Debian systems (9, 11, 12, 13)
- [ ] Add shellcheck linting to validate scripts

## Function-level pseudocode map

This is a concise, non-code map of the proposed top-level functions, their minimal contracts, and the conductor call order. Keep this spec in sync with `rackmill.sh` as it is refactored.

Operators will observe the script as it runs and respond to any errors or prompts during execution.

Backups should be performed in the function that owns the resource (for example, `apt_sources()` should back up apt files).

All functions should use `section()` and `step()` for logging, and avoid silent failures. 
Always allow the operator to see what is happening. Allow standard console output to be visible at all times.
Any irreversible actions (for example, removing user data) must be explicitly called out in the function comments and confirmed interactively by the operator before proceeding.

- setup()
  - purpose: ensure preconditions and detect OS release.
  - inputs: none (uses detected `VERSION_ID`), outputs: none.
  - key decisions: must confirm running as root; detect OS release; 

- apt_sources_setup()
  - purpose: audit `/etc/apt/sources.list` and `/etc/apt/sources.list.d` to determine whether changes are required.
  - inputs: `VERSION_ID`, `/etc/apt/sources.list`, and existing files under `/etc/apt/sources.list.d/*`.
  - outputs: audit summary and a decision flag indicating whether `apt_sources_apply()` should run; list of proposed changes (no modifications performed).

- apt_sources_apply()
  - purpose: create backups and apply approved changes to apt source files. run only if the setup phase determined changes are necessary.
  - inputs: decision flag and proposed changes from `apt_sources_setup()`.
  - outputs: `$BACKUPS` array variable containing paths of created backups. 

- aptdate()
  - purpose: run apt-get update, dist-upgrade, autoclean, and autoremove. perform smoke checks. 
  - inputs: none. rely on existing system configuration and sources.
  - outputs: standard console output.

- cleanup_prepare()
  - purpose: build and present a dry-run list of files/dirs to remove or truncate.
  - inputs: pattern list (maintained in the script), file system state, `$BACKUPS`.
  - outputs: which files were found to be deleted/truncated.
  - important: present the operator with a clear summary of what will be deleted/truncated, including `$BACKUPS`, and prompt for confirmation before proceeding to `cleanup_apply()`.

- cleanup_apply()
  - purpose: apply the confirmed cleanup actions safely.
  - inputs: confirmation from `cleanup_prepare()`; list of files to delete/truncate. 
  - outputs: standard console output
  - key decisions: if operator opted to approve the cleanup, delete immediately because explicit immediate purge was approved.

- configure()
  - purpose: set timezone & locale to Perth Australia, and hostname to "rackmill". regenerate host keys.
  - inputs: none. rely on existing system configuration and sources.
  - outputs: standard console output. log that an interactive session restart will be required to observe hostname/locale changes.

- report()
  - purpose: final summary and recovery hints.
  - inputs: artifacts created during run (backups, disabled files, logs); 
  - outputs: concise end-of-run report and recommended post-run checks.

- main() / conductor
  - purpose: call the functions in order as written above. set traps to restore shell state, centralize prompts so flow is predictable, and ensure fatal errors produce clear exit codes and messages.
  - inputs: none.
  - outputs: none.


