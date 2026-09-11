#!/bin/bash
#=================================================================================
# script name    : deploy.sh
# description    : clones the react app from github, builds it,
#                  and deploys it via nginx on this EC2 server.
# author         : qualibytes it academy (modified)
# usage          : sudo bash deploy.sh <GITHUB_REPO_URL>
# Example        : sudo bash deploy.sh https://github.com/owner/repo.git
#=================================================================================

set -euo pipefail

# -- colour codes for terminal output --
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# -- Helper functions --
info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# -- Read the github repo URL from the first argument ($1) --
GITHUB_REPO_URL="${1:-}"

if [ -z "$GITHUB_REPO_URL" ]; then
    error "Github repo missing. usage: sudo bash deploy.sh <GITHUB_REPO_URL>"
    exit 1
fi

# -- directory where the app will be cloned on EC2 --
APP_DIR="/home/ubuntu/qualibytes"

# -- Nginx web route where the final build will be served from --
WEB_DIR="/var/www/qualibytes"

echo ""
echo "=============================================================="
echo "qualibytes it academy - deployment script"
echo "=============================================================="
echo "Repo: $GITHUB_REPO_URL"
echo ""

# Ensure required system commands exist
command -v git >/dev/null 2>&1 || { error "git not found. Install git and try again."; exit 1; }
command -v npm >/dev/null 2>&1 || { error "npm not found. Install Node.js/npm and try again."; exit 1; }

# -- step 1: Get the latest code from Github --
info "step 1: getting latest code from Github..."

# create parent dir if needed
mkdir -p "$(dirname "$APP_DIR")"

if [ -d "$APP_DIR/.git" ]; then
    info "repo exists locally, pulling latest changes..."
    git -C "$APP_DIR" fetch --all --prune
    if git -C "$APP_DIR" rev-parse --verify origin/main >/dev/null 2>&1; then
        git -C "$APP_DIR" reset --hard origin/main
    else
        git -C "$APP_DIR" pull --rebase || git -C "$APP_DIR" pull
    fi
else
    info "cloning repository into $APP_DIR..."
    git clone --depth 1 "$GITHUB_REPO_URL" "$APP_DIR"
fi
success "latest code fetched from Github."

# -- step 2: Install Node.js dependencies --
info "step 2: installing npm packages..."
cd "$APP_DIR"

# Use npm ci when lockfile is present for reproducible installs
if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
    npm ci --production=false
else
    npm install
fi
success "npm packages installed."

# -- step 3: build the react app for production --
info "step 3: building the react app..."

# Ensure build script exists in package.json
if grep -q '"build"' package.json 2>/dev/null; then
    npm run build
else
    error "No build script found in package.json"
    exit 1
fi
success "react app built for production."

# -- step 4: copy the build output to the nginx web route --
info "step 4: copying build to web root..."

if [ ! -d "$APP_DIR/build" ]; then
    error "Build output not found at $APP_DIR/build"
    exit 1
fi

# Ensure the web directory exists and is writable by root (we use sudo to modify it)
sudo mkdir -p "$WEB_DIR"
# Safely remove contents of WEB_DIR
sudo rm -rf "${WEB_DIR:?}/"*
# Copy build contents
sudo cp -r "$APP_DIR/build"/* "$WEB_DIR/"
# Try to set ownership to www-data if the user/group exists
if getent passwd www-data >/dev/null 2>&1 && getent group www-data >/dev/null 2>&1; then
    sudo chown -R www-data:www-data "$WEB_DIR"
fi
success "build deployed to $WEB_DIR."

# -- step 5: reload nginx to serve the new files --
info "step 5: reloading nginx..."
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl reload nginx || sudo systemctl restart nginx
else
    sudo service nginx reload || sudo service nginx restart
fi
success "nginx reloaded."

echo ""
echo "=============================================================="
echo "Deployment completed successfully!"
echo "You can now access the app via the server's public IP or domain name."
echo "=============================================================="
