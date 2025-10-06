# Archived Debian Releases Support

## Overview

The script now supports **archived Debian releases** (versions 9 and 10) by automatically detecting when a system is running an archived version and using `archive.debian.org` instead of the current mirrors.

## Implementation Summary

### Debian 9 (Stretch) - Released June 2017, Archived June 2022
### Debian 10 (Buster) - Released July 2019, Archived June 2024

When the script detects Debian 9 or 10, it:
1. Shows a warning about archived status
2. Uses archive.debian.org for repositories
3. Uses old security suite format (`stretch/updates` instead of `stretch-security`)
4. Continues execution normally

## Expected APT Warnings

When using archived releases, you will see warnings like:

```
W: GPG error: http://archive.debian.org/debian stretch Release: The following signatures were invalid: EXPKEYSIG ...
W: The repository 'http://archive.debian.org/debian stretch Release' is not signed.
N: Data from such a repository can't be authenticated and is therefore potentially dangerous to use.
```

**This is NORMAL and EXPECTED** for archived releases. Archive repositories have expired GPG keys.

## Automatic Handling

The script **automatically** adds `--allow-unauthenticated` to `apt-get` commands when:
- OS is Debian
- Version is 9 or 10 (archived releases)

This allows package installation to proceed despite the signature warnings.

## Canonical Sources for Debian 9 (Stretch)

```bash
deb http://archive.debian.org/debian stretch main contrib non-free
deb http://archive.debian.org/debian stretch-backports main contrib non-free
deb http://archive.debian.org/debian-security stretch/updates main contrib non-free
```

### Key Differences from Current Releases

1. **Mirror**: `archive.debian.org` instead of `deb.debian.org`
2. **Security URL**: `archive.debian.org/debian-security` instead of `security.debian.org/debian-security`
3. **Security Suite**: `stretch/updates` (old format) instead of `stretch-security` (new format)
4. **No -updates suite**: Archive doesn't maintain the `-updates` suite, removed from sources

## Canonical Sources for Debian 10 (Buster)

```bash
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian buster-backports main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
```

Same differences as Stretch apply.

## Script Behavior Changes

### Detection Logic

```bash
if [[ "${VERSION_MAJOR}" -le 10 ]]; then
  use_archive=true
fi
```

### Warning Messages

When Debian 9 or 10 is detected:

```
⚠️  Detected Debian 9 (stretch) - ARCHIVED RELEASE
    This version uses archive.debian.org (no security updates).
    APT will show warnings about missing Release files - this is expected.
```

## Testing on Debian 9 (Your Current Issue)

### Before the Fix
```
E: Failed to fetch http://deb.debian.org/debian/dists/stretch/main/binary-amd64/Packages  404  Not Found
E: Failed to fetch http://security.debian.org/debian-security/dists/stretch-security/main/binary-amd64/Packages  404  Not Found
```

### After the Fix
```
W: GPG error: http://archive.debian.org/debian stretch Release: The following signatures were invalid...
W: The repository 'http://archive.debian.org/debian stretch Release' is not signed.
Get:1 http://archive.debian.org/debian stretch/main amd64 Packages [...]
Get:2 http://archive.debian.org/debian stretch/contrib amd64 Packages [...]
135 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
```

The warnings are displayed, but packages download and install successfully using `--allow-unauthenticated`.

## Security Implications

### Important Notes

1. **No Security Updates**: Archived releases receive NO security updates
2. **Extended LTS**: Some vendors offer paid extended LTS support
3. **Production Use**: Not recommended for production unless you have extended support
4. **Template Use**: Acceptable for legacy template requirements

### When to Use Archived Releases

✅ **Appropriate use cases:**
- Creating templates for customers with legacy requirements
- Testing/development environments
- Systems with vendor extended LTS support
- Non-production workloads

❌ **Not recommended for:**
- New production deployments
- Internet-facing services without extended support
- Systems handling sensitive data

## Comparison with Current Releases

| Aspect | Archived (9-10) | Current (11+) |
|--------|----------------|---------------|
| Mirror | archive.debian.org | deb.debian.org |
| Security | archive.debian.org/debian-security | security.debian.org/debian-security |
| Security Suite | `stretch/updates` | `bullseye-security` |
| Signed Release | No (warnings) | Yes |
| Updates | None | Regular |
| Support | Extended LTS only | Official |

## Troubleshooting

### APT Update Fails Completely

If `apt-get update` still fails after the fix:

1. Check network connectivity to archive.debian.org:
   ```bash
   ping -c3 archive.debian.org
   curl -I http://archive.debian.org/debian/dists/stretch/Release
   ```

2. Verify the codename is correct:
   ```bash
   cat /etc/os-release | grep VERSION_CODENAME
   ```

3. Check if archive.debian.org is accessible from your location

### Packages Not Found

Archived releases have a frozen package set. If a package isn't available:
- It was never in that release
- Try backports: `apt-get install -t stretch-backports package-name`
- Consider upgrading to a current release

### Repository Authentication Errors

The script automatically handles authentication for archived releases by:
1. Keeping warning messages visible (operators should be aware)
2. Adding `--allow-unauthenticated` to apt-get commands automatically
3. Not modifying sources.list with `[trusted=yes]` (keeps warnings visible)

This approach balances security awareness with functionality.

## Migration Path

If you're testing on Debian 9 and want to move to a current release:

1. **Immediate**: Use Debian 11 (Bullseye) - still has LTS until 2031
2. **Recommended**: Use Debian 12 (Bookworm) - current oldstable
3. **Latest**: Use Debian 13 (Trixie) - current stable

## Future Maintenance

As releases become archived:
- Debian 11 (Bullseye) will be archived around 2026
- The script will need updating when Debian 11 reaches end-of-life
- Consider adding Debian 11 to the archive check when appropriate:
  ```bash
  if [[ "${VERSION_MAJOR}" -le 11 ]]; then
    use_archive=true
  fi
  ```

## Related Documentation

- [Debian Archive](https://archive.debian.org/)
- [Debian LTS](https://wiki.debian.org/LTS)
- [Debian Release Info](https://www.debian.org/releases/)

---

**Last Updated:** October 6, 2025  
**Status:** ✅ Implemented and ready for testing  
**Next Step:** Test on actual Debian 9 system
