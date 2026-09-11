#!/bin/bash
#=================================================================================
#script name    : deploy.sh
#description    : clones the react app from github, builds it,
#                and deploys it via nginx on this EC2 server.
#author         : qualibytes it academy
#usage          : sudo bash deploy.sh <GITHUB_REPO_URL>
#Example        : sudo bash deploy.sh <GITHUB_REPO_URL>
#=================================================================================

# stop the script if any command fails
set -e

# -- colour codes for terminal output --
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# -- helper functions --
info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

# -- read the GitHub repo URL from the first argument ($1) --
GITHUB_REPO_URL="$1"

if [ -z "$GITHUB_REPO_URL" ]; then
    error "GitHub repo missing. usage: bash deploy.sh <GITHUB_REPO_URL>"
fi

# -- directory where the app will be cloned on EC2 --
APP_DIR="/home/ubuntu/qualibytes"

# -- nginx web route where the final build will be served from --
WEB_DIR="/var/www/qualibytes"

echo ""
echo "=============================================================="
echo "qualibytes it academy - deployment script"
echo "=============================================================="
echo "Repo: $GITHUB_REPO_URL"
echo ""

# -- step 1: get the latest code from Github --
info "step 1: getting latest code from Github..."
if [ -d "$APP_DIR/.git" ]; then
    # repo already exists, pull the latest changes
    cd "$APP_DIR"
    git pull origin main
else
    # first time - clone the full repo
    git clone "$GITHUB_REPO_URL" "$APP_DIR"
fi
success "latest code fetched from Github."

# -- step 2: install Node.js dependencies --
info "step 2: installing npm packages..."
cd "$APP_DIR"
npm install --silent
success "npm packages installed."

# -- step 3: build the react app for production --
info "step 3: building the react app..."
npm run build
success "react app built for production."

# -- step 4: copy the build output to the nginx web route --
info "step 4: copying build to web root..."
sudo mkdir -p "$WEB_DIR"
sudo rm -rf "$WEB_DIR"/*
sudo cp -r "$APP_DIR/build"/* "$WEB_DIR/"
sudo chown -R www-data:www-data "$WEB_DIR"
success "build deployed to $WEB_DIR."

# -- step 5: reload nginx to serve the new files --
info "step 5: reloading nginx..."
sudo systemctl reload nginx
success "nginx reloaded."

echo ""
echo "=============================================================="
echo "Deployment completed successfully!"
echo "You can now access the app via the server's public IP or domain name."
echo "==============================================================" 
