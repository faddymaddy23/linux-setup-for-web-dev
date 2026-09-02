# ============================================
# Copy files + permissions
# ============================================

# 1. Create destination directory
sudo mkdir -p /var/www/html/tuk/wp-content/updraft/

# 2. Copy everything from new-dev/ into updraft/
#    The /. ensures hidden files are copied too.
sudo cp -a /home/faddy/files/wordpress/clients/tukkuruk/backups/new-dev/. \
    /var/www/html/tuk/wp-content/updraft/

# 3. Set ownership for everything under wp-content
sudo chown -R faddy:www-data /var/www/html/tuk/wp-content

# 4. Give faddy and www-data read/write permissions
#    X adds execute permission only to directories
#    (and files that already have execute permission).
sudo chmod -R u+rwX,g+rwX /var/www/html/tuk/wp-content

# 5. Set setgid on all directories
#    New files/directories inherit the www-data group.
sudo find /var/www/html/tuk/wp-content -type d -exec chmod g+s {} +

# 6. Give faddy and www-data explicit ACL permissions
sudo setfacl -R -m u:faddy:rwX,g:www-data:rwX \
    /var/www/html/tuk/wp-content

# 7. Set default ACLs on all directories
#    New files/directories inherit faddy and www-data permissions.
sudo find /var/www/html/tuk/wp-content -type d -exec \
    setfacl -m d:u:faddy:rwx,d:g:www-data:rwx,d:m:rwx {} +



# Others
sudo chown -R faddy:www-data /var/www/html/propanel/wp-content/plugins
sudo find /var/www/html/propanel/wp-content/plugins -type d -exec chmod 775 {} \;
sudo find /var/www/html/propanel/wp-content/plugins -type f -exec chmod 664 {} \;
# Fix permissions for executables
find /var/www/html/propanel -type f -name vite -exec chmod +x {} \;
