server.setup.sh 
# !/bin/bash
#=================================================================================
#script name    : server.setup.sh
#description    : installs Node.js and Nginx on fresh EC2 instance
#author         : qualibytes it academy
#usage          : sudo bash server.setup.sh
#Run            : only once on a fresh EC2 instance
#=================================================================================

#stop the script immediately if any command fails
set -e


#-- colour codes for terminal output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m' 

#-- helper functions --
info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[ok]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; } 

echo "" 
echo "=============================================================="
echo "qualibytes it academy - server.setup.sh"
echo "=============================================================="   
echo ""

# -- step 1: make sure the script is run as root user
info "step 1: checking root permissions..."
if [ "$EUID" -ne 0 ]; then
    error "please run with sudo: sudo bash server.setup.sh"
fi
success "running as root."

# -- step 2: update system packages --
info "step 2: updating system packages..."
apt update -y > /dev/null 2>&1 
apt upgrade -y > /dev/null 2>&1
success "system packages updated."

# -- step 3: install curl (needed to download Node.js setup script) --\
info "step 3: installing curl..."
apt install curl -y > /dev/null 2>&1
success "curl installed."

# -- step 4: install Node.js v20 LTS --
info "step 4: installing Node.js v20 ..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt install nodejs -y > /dev/null 2>&1
success "Node.js $(node --version) and npm $(npm --version) installed."

# -- step 5: install Ngnix web server --
info "step 5: installing Nginx..."
apt install nginx -y > /dev/null 2>&1
success "Nginx installed."

# -- step 6: create the web root directory for our app --
info "step 6: creating web root directory ..."
mkdir -p /var/www/qualibytes
chown -R www-data:www-data /var/www/qualibytes
success "web root directory created at /var/www/qualibytes."

# -- step 7: write the Ngnix config file --
info "step 7: writing Nginx config file..."
cat > /etc/nginx/sites-available/qualibytes <<EOL
server {
    listen 80;
    server_name _;

    root /var/www/qualibytes;
    index index.html;

    # send all routes to index.html (required for react-router)
    location / {
        try_files $uri $uri/ /index.html; 
    }
}
EOL
success " nginx config file created "

# -- step 8: enable the site by creating a symlink --
info "step 8: enabling the site..."
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/qualibytes /etc/nginx/sites-enabled/qualibytes
success "site enabled."

# -- step 9: test the Nginx configuration --
info "step 9: start nginx..."
nginx -t
systemctl start nginx
systemctl enable nginx > /dev/null 2>&1
success "Nginx is running."

echo ""
echo "=============================================================="
echo "qualibytes it academy - server.setup.sh completed successfully"
echo "=============================================================="
echo ""
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"
echo "Nginx version: $(nginx -v 2>&1)"
echo ""
echo "next steps: run deploy.sh to deploy your react app."
echo ""
