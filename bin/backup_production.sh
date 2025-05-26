#!/bin/bash

# Create backup directory if it doesn't exist
mkdir -p ~/backup

# Get the latest backup file from the container
echo "Executing backup in production container..."
ssh root@116.203.224.90 "docker exec prova-backup /bin/bash -c 'pg_dump -h prova-db -U prova -d prova_production -F c -f /backups/backup_$(date +%Y%m%d_%H%M%S).dump'"

# Get the latest backup file
LATEST_BACKUP=$(ssh root@116.203.224.90 "docker exec prova-backup ls -t /backups | head -n1")

# Copy the backup file to local machine
echo "Downloading backup file: $LATEST_BACKUP"
scp root@116.203.224.90:/var/lib/docker/volumes/prova_backup_data/_data/$LATEST_BACKUP ~/backup/

echo "Backup completed successfully!"
echo "Backup file saved to: ~/backup/$LATEST_BACKUP"