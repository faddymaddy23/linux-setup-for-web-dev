# SSH info the server
ssh <cloudways_user>@<destination_server_ip> -p 22


# Check OS and existing tools
cat /etc/os-release
which tmux lftp
tmux -V
sftp --version


# Install tmux if missing
sudo apt-get update -y
sudo apt-get install -y tmux


# Start a persistent tmux session
tmux new -s wp_migration
## Detach (leave it running): press Ctrl+b then d
## Reattach later: tmux attach -t wp_migration
## List sessions: tmux ls
## Kill session when fully done: tmux kill-session -t wp_migration


# Test single file without resume support:
sftp -P <sftp_port> <source_sftp_user>@<source_host>
ls -la
cd /path/to/wordpress/wp-content/uploads/updraft
lcd ~/applications/<app_folder_name>/public_html/wp-content/uploads/updraft
get updraft_smallfile.txt


# Test single file with resume support:
sftp -P <sftp_port> <source_sftp_user>@<source_host> <<EOF
cd /path/to/wordpress/wp-content/uploads/updraft
lcd ~/applications/<app_folder_name>/public_html/wp-content/uploads/updraft
reget updraft_smallfile.txt
EOF


# Get file listing that needs to be migrated (single password prompt)
sftp <source_sftp_user>@<source_host> <<'EOF' > /tmp/listing.txt
cd /data/ROOT/wp-content/updraft
ls -1
EOF

cat /tmp/listing.txt


# Build a reget batch file from that listing
grep -v '^sftp>' /tmp/listing.txt | grep -v '^Connected' | grep -v '^ls' > /tmp/files.txt

{
echo "cd /data/ROOT/wp-content/updraft"
echo "lcd /var/www/html/public_html/wp-content/updraft"
awk '{print "reget \""$0"\""}' /tmp/files.txt
} > /tmp/batch.txt

cat /tmp/batch.txt


# Connect to remote sftp, navigate to correct directories and start getting files
sftp -P <sftp_port> <source_sftp_user>@<source_host>
cd /data/ROOT/wp-content/updraft
lcd /var/www/html/public_html/wp-content/updraft
reget "backup_2026-08-22-1026_Extreme_Ownership_Academy_e60e7df10022-db.gz"



# Restore Database
## backup existing db
mysqldump -h <host> -u <user> -p application24026 > ~/pre_restore_backup_$(date +%F).sql
ls -lh ~/pre_restore_backup_*.sql
tail -5 ~/pre_restore_backup_2026-08-22.sql

## Locate the backup files
cd /var/www/html/public_html/wp-content/updraft
ls -la
file backup_*-db.gz # Check if the DB backup is encrypted

## Copy and Decompress the DB backup
cp backup_XXXX-XX-XX-XXXX_sitename_hash-db.gz ~/restore_db.gz
cd ~
gunzip restore_db.gz
ls -lh ~/restore_db
head -50 ~/restore_db

## Check table prefix match wp-config by updating wp-config if needed
grep -m5 "CREATE TABLE" ~/restore_db
grep table_prefix /var/www/html/public_html/wp-config.php

## Import the database
mysql -h <host> -u <user> -p application24026 < ~/restore_db

## Verify import succeeded
mysql -h <host> -u <user> -p application24026 -e "SHOW TABLES;"
mysql -h <host> -u <user> -p application24026 -e "SELECT option_name, option_value FROM wp_options WHERE option_name IN ('siteurl','home');"

## Use WP-CLI for search-replace
which wp
wp search-replace 'academy.echelonfront.com' 'app24026.cloudwayssites.com' --all-tables --precise --recurse-objects --dry-run --path=/var/www/html/public_html --allow-root # dry-run
wp search-replace 'academy.echelonfront.com' 'app24026.cloudwayssites.com' --all-tables --precise --recurse-objects --path=/var/www/html/public_html --allow-root
wp search-replace 'http://app24026.cloudwayssites.com' 'https://app24026.cloudwayssites.com' --all-tables --precise --path=/var/www/html/public_html --allow-root # Also cover protocol-only variants in case any hardcoded

## Explicitly confirm siteurl/home
wp option get siteurl --path=/var/www/html/public_html --allow-root
wp option get home --path=/var/www/html/public_html --allow-root

## Update siteurl/home if still shows up
wp option update siteurl 'https://app24026.cloudwayssites.com' --path=/var/www/html/public_html --allow-root
wp option update home 'https://app24026.cloudwayssites.com' --path=/var/www/html/public_html --allow-root



# Restore plugins/themes/others
## Create a tmp folder
cd /var/www/html/public_html/wp-content
mkdir -p ~/restore_tmp
cd ~/restore_tmp

## Unzip each
unzip /var/www/html/public_html/wp-content/updraft/backup_2026-08-22-0448_Extreme_Ownership_Academy_0ab95e0f2807-mu-plugins.zip -d mu_plugins_extract
unzip /var/www/html/public_html/wp-content/updraft/backup_2026-08-22-0448_Extreme_Ownership_Academy_0ab95e0f2807-plugins.zip -d plugins_extract
unzip /var/www/html/public_html/wp-content/updraft/backup_2026-08-22-0448_Extreme_Ownership_Academy_0ab95e0f2807-themes.zip -d themes_extract
unzip /var/www/html/public_html/wp-content/updraft/backup_2026-08-22-0448_Extreme_Ownership_Academy_0ab95e0f2807-others.zip -d others_extract

## if uploads folder contain multiple zip files
mkdir -p ~/restore_tmp/uploads_extract
cd /var/www/html/public_html/wp-content/updraft

for f in backup_2026-08-22-0448_Extreme_Ownership_Academy_0ab95e0f2807-uploads*.zip; do
  echo "Extracting: $f"
  unzip -o "$f" -d ~/restore_tmp/uploads_extract/
done

## Verify each foler
ls plugins_extract/
ls themes_extract/
ls uploads_extract/
ls others_extract/

## Move into place
cp -rf ~/restore_tmp/mu_plugins_extract/mu-plugins/* /var/www/html/public_html/wp-content/mu-plugins/
cp -rf ~/restore_tmp/plugins_extract/plugins/* /var/www/html/public_html/wp-content/plugins/
cp -rf ~/restore_tmp/themes_extract/themes/* /var/www/html/public_html/wp-content/themes/
cp -rf ~/restore_tmp/uploads_extract/uploads/* /var/www/html/public_html/wp-content/uploads/
cp -rf ~/restore_tmp/others_extract/* /var/www/html/public_html/wp-content/

## Fix permissions
find /var/www/html/public_html/wp-content -type d -exec chmod 755 {} \;
find /var/www/html/public_html/wp-content -type f -exec chmod 644 {} \;


# Flush cache/rewrite rules and verify
wp cache flush --path=/var/www/html/public_html --allow-root
wp rewrite flush --path=/var/www/html/public_html --allow-root


# Cleanup sensitive files
shred -u ~/restore_db 2>/dev/null || rm -f ~/restore_db
rm -rf ~/restore_tmp

## After verifying everything delete the initial db backup as well
rm -f ~/pre_restore_backup_*.sql




# rsync - final migration
tmux ls
tmux kill-session -t wp_migration
tmux new -s rsync

## Create a new backup for second migration and fetch it
rsync -avz --progress \
  -e "ssh -p <port> -i ~/.ssh/file_name" \
  <user>@<server>:/var/www/webroot/ROOT/wp-content/updraft/backup_2026-08-31-0333_Extreme_Ownership_Academy_68299525f41a-db.gz \
  /var/www/html/public_html/wp-content/updraft/

cd /var/www/html/public_html/wp-content/updraft
cp backup_2026-08-31-0333_Extreme_Ownership_Academy_68299525f41a-db.gz ~/restore_db.gz
cd ~
gunzip restore_db.gz
ls -lh ~/restore_db
head -50 ~/restore_db

mysql -h <host> -u <user> -p application24026 < ~/restore_db

wp search-replace 'academy.echelonfront.com' 'app24026.cloudwayssites.com' --all-tables --precise --recurse-objects --path=/var/www/html/public_html --allow-root

wp option get siteurl --path=/var/www/html/public_html --allow-root
wp option get home --path=/var/www/html/public_html --allow-root

rsync -avn --checksum --delete \
  --exclude='updraft/' \
  --exclude='cache/' \
  --exclude='object-cache.php' \
  --exclude='wp-config.php' \
  source_server:/var/www/webroot/ROOT/wp-content/ \
  /var/www/html/public_html/wp-content/ \
  > ~/rsync_dryrun_$(date +%F_%H%M).log

less ~/rsync_dryrun_*.log
grep '^deleting' ~/rsync_dryrun_*.log

rsync -avz --checksum --delete --progress \
  --exclude='updraft/' \
  --exclude='cache/' \
  --exclude='object-cache.php' \
  --exclude='wp-config.php' \
  source_server:/var/www/webroot/ROOT/wp-content/ \
  /var/www/html/public_html/wp-content/ \
  2>&1 | tee ~/rsync_real_$(date +%F_%H%M).log

wp cache flush --path=/var/www/html/public_html --allow-root
wp rewrite flush --path=/var/www/html/public_html --allow-root
