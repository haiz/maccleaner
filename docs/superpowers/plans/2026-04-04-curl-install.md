# Curl Install Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MacCleaner installable via `curl -fsSL https://maccleaner.apps.caodev.top/install.sh | bash`

**Architecture:** GitHub Actions builds `MacCleanerApp` on tag push, wraps it into a minimal `.app` bundle, zips it, and SCPs it to a static nginx file server. The install script fetches `latest.txt` to get the current version, downloads the zip, and installs to `/Applications/`.

**Tech Stack:** Swift Package Manager, GitHub Actions (macos-latest), nginx, certbot, bash

---

## Files

| File | Action | Purpose |
|------|--------|---------|
| `.github/workflows/release.yml` | Create | CI/CD: build → bundle → zip → deploy on git tag |
| `install.sh` (local copy) | Create | Install script (uploaded to server) |
| Server: `/etc/nginx/sites-available/maccleaner.apps.caodev.top` | Create on server | nginx vhost for static file serving |
| Server: `/var/www/maccleaner.apps.caodev.top/` | Create on server | Document root with releases/ dir |

---

## Task 1: Add DNS Record

**Files:** None (DNS control panel change)

- [ ] **Step 1: Add A record**

In your DNS provider's control panel, add:

```
Type:  A
Name:  maccleaner.apps
Value: 62.171.137.81
TTL:   300
```

- [ ] **Step 2: Verify propagation**

```bash
dig maccleaner.apps.caodev.top +short
```

Expected: `62.171.137.81`

(May take a few minutes. Re-run until it resolves.)

---

## Task 2: Server Directory & nginx Config

**Files:**
- Create on server: `/var/www/maccleaner.apps.caodev.top/`
- Create on server: `/etc/nginx/sites-available/maccleaner.apps.caodev.top`

- [ ] **Step 1: Create directory structure**

```bash
ssh caodev "mkdir -p /var/www/maccleaner.apps.caodev.top/releases"
```

- [ ] **Step 2: Write nginx config**

```bash
ssh caodev "cat > /etc/nginx/sites-available/maccleaner.apps.caodev.top << 'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name maccleaner.apps.caodev.top;

    root /var/www/maccleaner.apps.caodev.top;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Serve install.sh as plain text so | bash works
    location = /install.sh {
        add_header Content-Type text/plain;
    }

    # Cache release zips aggressively, text files not at all
    location /releases/ {
        expires 30d;
        add_header Cache-Control \"public, immutable\";
    }

    location ~* \.(txt|sh)$ {
        expires -1;
        add_header Cache-Control \"no-store\";
    }
}
NGINX"
```

- [ ] **Step 3: Enable site**

```bash
ssh caodev "ln -sf /etc/nginx/sites-available/maccleaner.apps.caodev.top /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx"
```

Expected output: `nginx: configuration file /etc/nginx/nginx.conf test is successful`

- [ ] **Step 4: Commit**

```bash
git commit --allow-empty -m "chore: server nginx config created for maccleaner.apps.caodev.top"
```

---

## Task 3: SSL Certificate

**Files:** None (certbot manages certs on server)

- [ ] **Step 1: Verify DNS resolved before running certbot**

```bash
dig maccleaner.apps.caodev.top +short
```

Expected: `62.171.137.81` — do not proceed until this returns the IP.

- [ ] **Step 2: Obtain certificate**

```bash
ssh caodev "certbot --nginx -d maccleaner.apps.caodev.top --non-interactive --agree-tos -m admin@caodev.top"
```

Expected: `Successfully deployed certificate for maccleaner.apps.caodev.top`

- [ ] **Step 3: Verify HTTPS**

```bash
curl -fsSL https://maccleaner.apps.caodev.top/ 2>&1 | head -5
```

Expected: 404 or empty (no index yet — that's fine, just confirms TLS works).

---

## Task 4: Write and Upload install.sh

**Files:**
- Create: `install.sh` (local, then uploaded)

- [ ] **Step 1: Write install.sh locally**

Create `install.sh` in the repo root:

```bash
#!/bin/bash
set -e

BASE_URL="https://maccleaner.apps.caodev.top"
APP_NAME="MacCleanerApp"
INSTALL_DIR="/Applications"

# macOS only
if [ "$(uname)" != "Darwin" ]; then
  echo "Error: MacCleaner requires macOS." >&2
  exit 1
fi

echo "Fetching latest version..."
VERSION=$(curl -fsSL "$BASE_URL/latest.txt")

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine latest version." >&2
  exit 1
fi

echo "Installing MacCleaner $VERSION..."

TMP_DIR=$(mktemp -d)
ZIP_PATH="$TMP_DIR/MacCleaner.zip"

curl -fsSL "$BASE_URL/releases/MacCleaner-$VERSION.zip" -o "$ZIP_PATH"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
  echo "Removing existing installation..."
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

mv "$TMP_DIR/$APP_NAME.app" "$INSTALL_DIR/"
rm -rf "$TMP_DIR"

echo ""
echo "MacCleaner $VERSION installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "First launch: right-click the app and choose Open"
echo "(macOS Gatekeeper requires this for unsigned apps)"
```

- [ ] **Step 2: Upload to server**

```bash
scp install.sh caodev:/var/www/maccleaner.apps.caodev.top/install.sh
```

- [ ] **Step 3: Verify it's reachable**

```bash
curl -fsSL https://maccleaner.apps.caodev.top/install.sh | head -5
```

Expected:
```
#!/bin/bash
set -e

BASE_URL="https://maccleaner.apps.caodev.top"
APP_NAME="MacCleanerApp"
```

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add curl install script"
```

---

## Task 5: GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create workflow file**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Get version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Build MacCleanerApp
        run: swift build -c release --product MacCleanerApp

      - name: Create .app bundle
        run: |
          VERSION=${{ steps.version.outputs.VERSION }}
          BUNDLE_VERSION="${VERSION#v}"
          mkdir -p MacCleanerApp.app/Contents/MacOS

          cp .build/release/MacCleanerApp MacCleanerApp.app/Contents/MacOS/

          cat > MacCleanerApp.app/Contents/Info.plist << 'PLIST'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
              <key>CFBundleExecutable</key>
              <string>MacCleanerApp</string>
              <key>CFBundleIdentifier</key>
              <string>top.caodev.maccleaner</string>
              <key>CFBundleName</key>
              <string>MacCleaner</string>
              <key>CFBundlePackageType</key>
              <string>APPL</string>
              <key>CFBundleShortVersionString</key>
              <string>BUNDLE_VERSION_PLACEHOLDER</string>
              <key>CFBundleVersion</key>
              <string>1</string>
              <key>LSMinimumSystemVersion</key>
              <string>13.0</string>
              <key>NSPrincipalClass</key>
              <string>NSApplication</string>
              <key>NSHighResolutionCapable</key>
              <true/>
          </dict>
          </plist>
          PLIST

          sed -i '' "s/BUNDLE_VERSION_PLACEHOLDER/${BUNDLE_VERSION}/" MacCleanerApp.app/Contents/Info.plist

      - name: Zip .app bundle
        run: |
          VERSION=${{ steps.version.outputs.VERSION }}
          zip -r "MacCleaner-${VERSION}.zip" MacCleanerApp.app

      - name: Deploy to server
        env:
          SSH_KEY: ${{ secrets.DEPLOY_SSH_KEY }}
          DEPLOY_USER: ${{ secrets.DEPLOY_USER }}
          DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
          VERSION: ${{ steps.version.outputs.VERSION }}
        run: |
          echo "$SSH_KEY" > /tmp/deploy_key
          chmod 600 /tmp/deploy_key

          SCP_OPTS="-i /tmp/deploy_key -o StrictHostKeyChecking=no"

          scp $SCP_OPTS \
            "MacCleaner-${VERSION}.zip" \
            "${DEPLOY_USER}@${DEPLOY_HOST}:/var/www/maccleaner.apps.caodev.top/releases/"

          ssh $SCP_OPTS "${DEPLOY_USER}@${DEPLOY_HOST}" \
            "echo '${VERSION}' > /var/www/maccleaner.apps.caodev.top/latest.txt"

          rm /tmp/deploy_key

      - name: Verify deployment
        env:
          VERSION: ${{ steps.version.outputs.VERSION }}
        run: |
          sleep 3
          LATEST=$(curl -fsSL https://maccleaner.apps.caodev.top/latest.txt)
          if [ "$LATEST" != "$VERSION" ]; then
            echo "Deployment verification failed: latest.txt contains '$LATEST', expected '$VERSION'"
            exit 1
          fi
          echo "Deployed $VERSION successfully"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions release workflow"
```

---

## Task 6: Configure GitHub Secrets

**Files:** None (GitHub repo settings)

- [ ] **Step 1: Generate deploy SSH key pair (on your Mac)**

```bash
ssh-keygen -t ed25519 -C "github-actions-maccleaner" -f ~/.ssh/maccleaner_deploy -N ""
```

Output files:
- `~/.ssh/maccleaner_deploy` — private key (goes into GitHub)
- `~/.ssh/maccleaner_deploy.pub` — public key (goes onto server)

- [ ] **Step 2: Add public key to server**

```bash
cat ~/.ssh/maccleaner_deploy.pub | ssh caodev "cat >> ~/.ssh/authorized_keys"
```

Verify:
```bash
ssh -i ~/.ssh/maccleaner_deploy root@62.171.137.81 "echo ok"
```

Expected: `ok`

- [ ] **Step 3: Add secrets to GitHub repo**

Go to: https://github.com/haiz/maccleaner/settings/secrets/actions

Add three secrets:

| Secret name | Value |
|-------------|-------|
| `DEPLOY_SSH_KEY` | contents of `~/.ssh/maccleaner_deploy` (the private key file, include the full `-----BEGIN...-----END` lines) |
| `DEPLOY_HOST` | `62.171.137.81` |
| `DEPLOY_USER` | `root` |

To get the private key value:
```bash
cat ~/.ssh/maccleaner_deploy
```

---

## Task 7: First Release — End-to-End Test

**Files:** None

- [ ] **Step 1: Push all changes**

```bash
git push origin main
```

- [ ] **Step 2: Tag and push to trigger the workflow**

```bash
git tag v0.1.0
git push origin v0.1.0
```

- [ ] **Step 3: Watch the workflow run**

Go to: https://github.com/haiz/maccleaner/actions

Watch the `Release` workflow. All steps should go green. Expected duration: ~5 minutes (Swift build on macOS runner).

- [ ] **Step 4: Verify server artifacts**

```bash
ssh caodev "cat /var/www/maccleaner.apps.caodev.top/latest.txt"
```

Expected: `v0.1.0`

```bash
ssh caodev "ls -lh /var/www/maccleaner.apps.caodev.top/releases/"
```

Expected: `MacCleaner-v0.1.0.zip`

- [ ] **Step 5: Run the install script**

```bash
curl -fsSL https://maccleaner.apps.caodev.top/install.sh | bash
```

Expected output:
```
Fetching latest version...
Installing MacCleaner v0.1.0...
MacCleaner v0.1.0 installed to /Applications/MacCleanerApp.app

First launch: right-click the app and choose Open
(macOS Gatekeeper requires this for unsigned apps)
```

- [ ] **Step 6: Verify app installed**

```bash
ls -la /Applications/MacCleanerApp.app/Contents/MacOS/MacCleanerApp
```

Expected: the binary exists and is executable.

- [ ] **Step 7: Launch app to confirm it runs**

```bash
open /Applications/MacCleanerApp.app
```

Right-click → Open if Gatekeeper prompts. The MacCleaner window should appear.
