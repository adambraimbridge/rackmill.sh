#!/usr/bin/env bash
# =============================================
# Rackmill VM Baseline Setup Script
#
# Purpose:
# - Apply a small, reproducible baseline to Rackmill VM templates (hostname, apt sources,
#   system updates, timezone/locale, and minimal housekeeping).
# =============================================

set -euo pipefail

GREEN="\e[32m"; CYAN="\e[36m"; RESET="\e[0m"
section(){ echo -e "${CYAN}\n========== $1 ==========${RESET}\n"; }
step(){    echo -e "${GREEN}\n>>> $1${RESET}"; }

[ "$(id -u)" -eq 0 ] || { echo "Please run as root."; exit 1; }

if command -v lsb_release; then
	VERSION_ID=$(lsb_release -r -s)
else
	. /etc/os-release || true
	VERSION_ID=${VERSION_ID:-}
fi
VERSION_MAJOR=${VERSION_ID%%.*}
VERSION_MAJOR=${VERSION_MAJOR:-0}

section "APT sources"
step "Backing up sources.list ..."
cp -a /etc/apt/sources.list{,.bak}

# If there are active sources in /etc/apt/sources.list.d, prefer disabling
# the main /etc/apt/sources.list to avoid duplicate or conflicting entries.
# This is interactive and reversible: the original file was already backed up
# to /etc/apt/sources.list.bak above.
step "Checking /etc/apt/sources.list.d for additional source files..."

# preserve nullglob state so unmatched globs don't expand to literal patterns
if shopt -q nullglob 2>/dev/null; then
	_prev_nullglob=1
else
	_prev_nullglob=0
fi
shopt -s nullglob || true

d_with_deb=()
for f in /etc/apt/sources.list.d/*; do
	[ -f "$f" ] || continue
	if grep -qE '^\s*deb(\s|$)' "$f" 2>/dev/null; then
		d_with_deb+=("$f")
	fi
done

# restore nullglob
if [ "${_prev_nullglob:-0}" -eq 0 ]; then
	shopt -u nullglob || true
fi

if [ "${#d_with_deb[@]}" -gt 0 ]; then
	step "Found active 'deb' entries in /etc/apt/sources.list.d:" 
	# Track suites found per base codename and which files contributed them
	declare -A _base_files
	declare -A _base_suites
	_bases=()
	for f in "${d_with_deb[@]}"; do
		printf "  - %s\n" "$f"
		# show non-commented deb lines for quick audit
		grep -nE '^\s*deb(\s|$)' "$f" | sed 's/^/      /' || true

		# collect suites from this file
		_lines=$(grep -E '^\s*deb(\s|$)' "$f" 2>/dev/null || true)
		while IFS= read -r _line; do
			# remove leading/trailing space and any bracketed options after 'deb'
			_san=$(printf '%s' "$_line" | sed -E 's/^\s*deb\s*\[[^]]*\]\s*/deb /; s/^\s*//; s/\s*$//')
			# extract the suite field (usually the 3rd token after 'deb' or 4th if options present)
			_suite=$(printf '%s' "$_san" | awk '{print $3}')
			[ -z "$_suite" ] && continue
			# base codename without -security/-updates/-backports suffix
			_base=$(printf '%s' "$_suite" | sed -E 's/(-security|-updates|-backports)$//')
			if [ -z "${_base_suites[$_base]:-}" ]; then
				_bases+=("$_base")
			fi
			# record suite and file
			_base_suites[$_base]="${_base_suites[$_base]:-} $_suite"
			_base_files[$_base]="${_base_files[$_base]:-} $f"
		done <<< "$_lines"
	done
	printf "\nThe file /etc/apt/sources.list was backed up to /etc/apt/sources.list.bak.\n"
	printf "It's recommended to disable the main /etc/apt/sources.list to avoid duplicate/conflicting entries.\n"

	# Analyze collected bases/suites for mixed codenames or missing -updates/-security
	# Normalize unique bases
	_unique_bases=()
	for _b in "${_bases[@]}"; do
		# skip empty
		[ -z "$_b" ] && continue
		case " ${_unique_bases[*]} " in
			*" $_b "*) ;;
			*) _unique_bases+=("$_b") ;;
		esac
	done

	if [ "${#_unique_bases[@]}" -gt 1 ]; then
		step "Warning: mixed Ubuntu codenames detected across /etc/apt/sources.list.d files:"
		for _b in "${_unique_bases[@]}"; do
			printf "  - %s (files:%s)\n" "$_b" "${_base_files[$_b]:-}"
		done
		step "Mixed codenames can lead to inconsistent package pools; please consolidate to a single release where possible."
	fi

	# For each base, ensure -updates and -security suites are present (or warn)
	for _b in "${_unique_bases[@]}"; do
		_suites=" ${_base_suites[$_b]:-} "
		_missing=()
		if [[ "$_suites" != *" ${_b}-updates " ]]; then
			_missing+=("${_b}-updates")
		fi
		if [[ "$_suites" != *" ${_b}-security " ]]; then
			_missing+=("${_b}-security")
		fi
		if [ ${#_missing[@]} -gt 0 ]; then
			step "Notice: for codename '$_b', the following suites appear missing in /etc/apt/sources.list.d: ${_missing[*]}"
			step "Files contributing entries for '$_b': ${_base_files[$_b]:-}"
			step "Consider adding the missing suites or keeping the main /etc/apt/sources.list (it contains standard -updates/-security entries)."
		fi
	done
	printf "Disable /etc/apt/sources.list now by renaming to /etc/apt/sources.list.disabled? [y/N]: "
	read -r _disable_ans || _disable_ans="n"
	case "${_disable_ans,,}" in
		y|yes)
			if [ -f /etc/apt/sources.list ]; then
				if mv /etc/apt/sources.list /etc/apt/sources.list.disabled; then
					step "Renamed /etc/apt/sources.list -> /etc/apt/sources.list.disabled"
				else
					echo "Warning: failed to rename /etc/apt/sources.list" >&2
				fi
			else
				step "/etc/apt/sources.list not present; nothing to disable."
			fi
			;;
		*)
			step "Leaving /etc/apt/sources.list in place. Please audit entries manually if needed."
			;;
	esac
fi

# Write apt sources for a given codename and mirror base
write_sources() {
	codename="$1"
	mirror="${2:-archive.ubuntu.com/ubuntu}"
	security="${3:-security.ubuntu.com/ubuntu}"
	cat >/etc/apt/sources.list <<EOF
deb http://$mirror $codename main restricted universe multiverse
deb http://$mirror ${codename}-updates main restricted universe multiverse
deb http://$mirror ${codename}-backports main restricted universe multiverse
deb http://$security ${codename}-security main restricted universe multiverse
EOF
}

# Select apt sources based on detected Ubuntu version
case "$VERSION_ID" in
	25.*) write_sources plucky ;;
	24.*) write_sources noble ;;
	22.*) write_sources jammy ;;
	20.*) write_sources focal ;;
	18.*) write_sources bionic ;;
	16.*) write_sources xenial ;;
	14.*) write_sources trusty ;;
	*) step "Unknown or unsupported Ubuntu version: $VERSION_ID. Leaving sources.list unchanged." ;;
esac

section "System upgrade"

step "Clearing stale indices ..."
rm -rf /var/lib/apt/lists/*

step "Running apt-get update (primary mirrors) ..."
apt-get update

step "Applying upgrades that may add/remove deps (dist-upgrade) ..."
apt-get dist-upgrade

step "Removing unneeded packages ..."
apt-get autoremove
apt-get autoclean

section "Configuration"

section "Timezone & Locale"
step "Setting timezone to Australia/Perth ..."
timedatectl set-timezone Australia/Perth || true

step "Installing locales ..."
apt-get install locales
locale-gen en_AU.UTF-8
update-locale LANG=en_AU.UTF-8 LANGUAGE="en_AU:en" LC_TIME=en_AU.UTF-8

step "Current locale:"
locale

step "Setting hostname to rackmill ..."
hostnamectl set-hostname rackmill || true

step "Baseline complete for $VERSION_ID."

section "Remove sensitive data"

step "Preparing cleanup (dry-run) ..."
patterns=(
	# Machine identifiers - should be cleared in templates
	/etc/machine-id                # truncate: ensures unique machine id per clone
	/var/lib/dbus/machine-id       # truncate: dbus machine id (may duplicate /etc)
	/var/lib/systemd/machine-id    # truncate: systemd machine id (some systems)

	# System randomness/state - clear so guests regenerate
	/var/lib/systemd/random-seed   # remove: avoid reusing VM randomness across images

	# SSH host keys - always remove and regenerate on first boot
	/etc/ssh/ssh_host_*            # remove files matching host key prefixes

	# Root-specific files
	/root/.ssh/authorized_keys     # remove: prevent baked-in root SSH keys
	/root/.wget-hsts               # remove: wget HSTS cache
	/root/.Xauthority              # remove: X auth tokens for root
	/root/.bash_history            # remove: root shell history
	/root/.cache                   # remove directory: caches
	/root/.nano                    # remove editor state

	# Per-user files under /home
	/home/*/.ssh/authorized_keys   # remove: user SSH authorized keys
	/home/*/.wget-hsts             # remove: per-user wget HSTS
	/home/*/.Xauthority            # remove: per-user X auth tokens
	/home/*/.bash_history          # remove: per-user shell history

	# Temp space
	/tmp/*                         # remove: user/system temp files (entries under /tmp)
)

cleanup_preview(){
	step "The following cleanup actions would be performed (dry-run):"

	# Use nullglob temporarily so unmatched globs don't expand to
	# literal patterns. Preserve/restore previous state.
	if shopt -q nullglob; then
		_prev_nullglob=1
	else
		_prev_nullglob=0
	fi
	shopt -s nullglob || true

	for pat in "${patterns[@]}"; do
		printed=false
		for a in $pat; do
			if [ -e "$a" ]; then
				if [ "$printed" = false ]; then
					printf "  - matches for: %s\n" "$pat"
					printed=true
				fi
				printf "      %s\n" "$a"
			fi
		done
	done

	# restore nullglob state
       if [ "${_prev_nullglob:-0}" -eq 0 ]; then
	       shopt -u nullglob || true
	fi

	step "  - run 'cloud-init clean --logs' if cloud-init is installed"
	step "  - regenerate fresh SSH host keys (ssh-keygen -A)"
	step "  - truncate files in /var/log"
	step "  - clear in-memory shell history (history -c)"
}

cleanup_apply(){
	# Use nullglob so unmatched globs don't expand to literal patterns.
	# Preserve previous nullglob state and restore it after.
	if shopt -q nullglob; then
		_prev_nullglob=1
	else
		_prev_nullglob=0
	fi
	shopt -s nullglob || true

	for pat in "${patterns[@]}"; do
		for a in $pat; do
			if [ -e "$a" ]; then
				if [ -d "$a" ]; then
					# directory: remove recursively
					rm -rf -- "$a" || echo "Warning: failed to remove directory $a" >&2
				else
					# regular file or symlink: remove file
					rm -f -- "$a" || echo "Warning: failed to remove $a" >&2
				fi
			fi
		done
	done

	step "Verifying sensitive files and patterns are removed ..."
	missing=0
	for pat in "${patterns[@]}"; do
		for a in $pat; do
			if [ -e "$a" ]; then
				step "Warning: $a still exists after cleanup"
				missing=1
			fi
		done
	done
	if [ "$missing" -eq 0 ]; then
		step "All sensitive files and patterns have been removed."
	else
		step "Some sensitive files remain. Please check warnings above."
	fi

	# restore nullglob state
       if [ "${_prev_nullglob:-0}" -eq 0 ]; then
	       shopt -u nullglob || true
	fi

	step "Generating fresh SSH host keys ..."
	if command -v ssh-keygen; then
		if ! ssh-keygen -A; then
			echo "Warning: ssh-keygen -A failed" >&2
		fi
	else
		echo "Warning: ssh-keygen not found; skipping host key generation" >&2
	fi

	# If cloud-init is installed, clean instance specific state and logs so the
	# template will allow cloud-init to run as first-boot on clones.
	if command -v cloud-init; then
		step "Detected cloud-init; running 'cloud-init clean --logs'..."
		if ! cloud-init clean --logs; then
			echo "Warning: cloud-init clean failed" >&2
		fi
	else
		step "cloud-init not present; skipping cloud-init clean"
	fi

	# Clear in-memory history where available; non-interactive shells may not support this.
	history -c || echo "Note: history -c not available in this shell" >&2
}

cleanup_preview
printf "\nApply these cleanup actions now? [y/N]: "
read -r ans || ans="n"
case "${ans,,}" in
	y|yes)
		step "Applying cleanup ..."
		cleanup_apply
		step "Cleanup complete." ;;
	*)
		step "Cleanup skipped (dry-run only)." ;;
esac

section "Final notes"

step "Reminder: For best security, run \`rm rackmill.sh .bash_history; history -c;\` in your interactive shell."
step "You'll need to exit and restart your SSH session if you want to see the new hostname and locale.\n\n\n"

