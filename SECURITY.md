# Security Policy

SPCLib is an archive of Lua scripts and resources for Halo: PC and Custom
Edition, targeting SAPP, Phasor, and Chimera. This document explains how to
report a vulnerability and what to expect.

## Supported Versions

This repository is an archive. Scripts carry their own version information, and
fixes are applied to the latest version on `main`.

| Version          | Supported |
| ---------------- | --------- |
| Latest on `main` | Yes       |
| Older commits    | No        |
| Forks            | No        |

## Reporting a Vulnerability

**Please do not open a public issue for security problems.**

1. **GitHub Private Vulnerability Reporting** (preferred). Use the
   [Report a vulnerability](https://github.com/Chalwk/SPCLib/security/advisories/new)
   button on the Security tab.
2. **Email**. Email [chalwk.dev@gmail.com](mailto:chalwk.dev@gmail.com) with
   "SECURITY" in the subject line.

### What to include

- The script name and version
- Which runtime it targets (SAPP, Phasor, or Chimera)
- A clear description of the issue
- Steps to reproduce
- The impact you believe it has

Redact any real server IPs, admin credentials, or player data.

## Scope

### In scope

- Malicious code in a submitted script (backdoors, unexpected network calls,
  unauthorised command execution)
- Command injection through chat, admin commands, or script inputs
- Hardcoded credentials or API keys in scripts or configs
- Scripts that leak server information
- Unsafe file operations

### Out of scope

- Issues in SAPP, Phasor, or Chimera themselves (report those upstream)
- Server misconfiguration
- Uptime or availability
- Cosmetic bugs or feature requests

## What to expect

- **Acknowledgement:** within 7 days
- **Initial assessment:** within 14 days
- **Fix or removal:** usually within 30 days for confirmed issues
- **Public disclosure:** coordinated with you

## Using SPCLib scripts safely

- Read any script before running it on a live server.
- Check for unexpected network calls or file writes.
- Keep a backup of your server config before installing anything new.
- Report suspicious submissions.

## Automated security

- Dependabot alerts and security updates
- Secret scanning with push protection