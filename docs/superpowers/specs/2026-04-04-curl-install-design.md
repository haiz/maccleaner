# Curl Install Script — Design Spec

**Date:** 2026-04-04  
**Domain:** `maccleaner.apps.caodev.top`  
**Scope:** GUI app (`MacCleanerApp`) only

---

## Overview

Make MacCleaner installable via:

```bash
curl -fsSL https://maccleaner.apps.caodev.top/install.sh | bash
```

GitHub Actions builds the app on tag push, packages it, and deploys to a static file server. The install script fetches the latest version and installs `MacCleanerApp.app` to `/Applications/`.

---

## Architecture

```
git tag v1.0.0 && git push --tags
         │
         ▼
GitHub Actions (macos-latest runner)
  1. swift build -c release --product MacCleanerApp
  2. Wrap binary into MacCleanerApp.app bundle
  3. zip MacCleanerApp.app → MacCleaner-v1.0.0.zip
  4. SCP zip → server /var/www/maccleaner.apps.caodev.top/releases/
  5. Update latest.txt → "v1.0.0"
         │
         ▼
Server: maccleaner.apps.caodev.top (nginx static file server)
  /var/www/maccleaner.apps.caodev.top/
  ├── install.sh
  ├── latest.txt
  └── releases/
      └── MacCleaner-v1.0.0.zip
         │
         ▼
User:
  curl -fsSL https://maccleaner.apps.caodev.top/install.sh | bash
```

---

## Components

### 1. GitHub Actions Workflow — `.github/workflows/release.yml`

- **Trigger:** push to tags matching `v*.*.*`
- **Runner:** `macos-latest`
- **GitHub Secrets required:**
  - `DEPLOY_SSH_KEY` — private key for SSH to server
  - `DEPLOY_HOST` — `maccleaner.apps.caodev.top`
  - `DEPLOY_USER` — server SSH user

**Steps:**
1. Checkout code
2. `swift build -c release --product MacCleanerApp`
3. Create `.app` bundle structure from the compiled binary
4. Zip bundle → `MacCleaner-{tag}.zip`
5. SCP zip to server `releases/` directory
6. SSH update `latest.txt` with the tag version

### 2. `.app` Bundle Structure (created in CI)

Since this is a Swift Package Manager project, `swift build` produces a plain binary. CI wraps it into a minimal app bundle:

```
MacCleanerApp.app/
└── Contents/
    ├── Info.plist      ← CFBundleName, CFBundleExecutable, NSPrincipalClass, etc.
    └── MacOS/
        └── MacCleanerApp   ← compiled binary
```

> **Note:** The app will be unsigned. macOS Gatekeeper will block it on first launch — users must right-click → Open. Proper signing requires an Apple Developer ID ($99/year).

### 3. Server Setup

- **OS:** Ubuntu 24.04 (existing server)
- **Web server:** nginx serving static files
- **SSL:** certbot (Let's Encrypt), same pattern as other vhosts
- **Document root:** `/var/www/maccleaner.apps.caodev.top/`
- **Directory layout:**

```
/var/www/maccleaner.apps.caodev.top/
├── install.sh       ← uploaded once, lives on server
├── latest.txt       ← overwritten on each release (e.g. "v1.0.0")
└── releases/
    ├── MacCleaner-v1.0.0.zip
    └── MacCleaner-v1.1.0.zip
```

- `install.sh` is served with `Content-Type: text/plain` so `| bash` works

### 4. Install Script — `install.sh`

```
1. Verify running on macOS (exit with error otherwise)
2. GET /latest.txt → version string (e.g. "v1.0.0")
3. Download /releases/MacCleaner-{version}.zip to /tmp/
4. Unzip to /tmp/MacCleaner/
5. Remove existing /Applications/MacCleanerApp.app if present
6. Move MacCleanerApp.app → /Applications/
7. Clean up /tmp files
8. Print success message
```

---

## Deploy Flow

**Releasing a new version:**
```bash
git tag v1.0.0
git push origin v1.0.0
# GitHub Actions triggers automatically
```

**CI deploy steps:**
```
scp MacCleaner-v1.0.0.zip {user}@{host}:/var/www/maccleaner.apps.caodev.top/releases/
ssh {user}@{host} "echo v1.0.0 > /var/www/maccleaner.apps.caodev.top/latest.txt"
```

---

## Files to Create

| File | Location |
|------|----------|
| GitHub Actions workflow | `.github/workflows/release.yml` |
| Nginx vhost config | on server: `/etc/nginx/sites-available/maccleaner.apps.caodev.top` |
| Install script | on server: `/var/www/maccleaner.apps.caodev.top/install.sh` |

---

## Constraints & Limitations

- macOS-only install (script exits on other platforms)
- App is unsigned — Gatekeeper prompt on first open
- No checksum validation (can be added later)
- Requires the server user to have write access to `/var/www/maccleaner.apps.caodev.top/`
