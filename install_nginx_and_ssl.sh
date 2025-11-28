#!/bin/bash

# Check for domain argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <DomainOrIPAddress>"
    exit 1
fi

DOMAIN=$1

# Step 1: Install Nginx web server
sudo apt install -y nginx

# Step 2: Allow Nginx traffic through the firewall
sudo ufw allow 'Nginx Full'

# Step 3: Enable the firewall (optional if UFW is already active)
sudo ufw enable

# Step 8: Install Certbot for obtaining SSL certificates
sudo apt install -y certbot python3-certbot-nginx

# Step 9: Reminder to create an A record in your DNS provider
echo "Please make sure an A record exists for $DOMAIN in your DNS provider (like IONOS)."
read -p "Press Enter to continue once done."

# Step 10: Obtain and apply SSL certificate for the domain
sudo certbot --nginx -d $DOMAIN

# Step 11-12: Inform the user to manually edit and enable domain-specific configuration
echo "Please manually edit /etc/nginx/sites-available/api.domain (if needed) and create the symbolic link:"
echo "sudo nano /etc/nginx/sites-available/api.domain"
echo "sudo ln -s /etc/nginx/sites-available/api.domain /etc/nginx/sites-enabled/"

# Step 13: Test Nginx configuration for syntax errors (optional step)
sudo nginx -t

# Step 14: Reload Nginx to apply new configuration
sudo systemctl reload nginx

echo "✅ Nginx installed, firewall configured, and SSL certificate applied for $DOMAIN."
