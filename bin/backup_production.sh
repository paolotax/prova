#!/bin/bash

# Create backup directory if it doesn't exist
mkdir -p ~/backup
rm -f ~/backup/new_backup.dmp

LATEST_BACKUP="backup_$(date +%Y%m%d_%H%M%S).dump"

# Create the dump inside the container
echo "Executing backup in production container..."
ssh root@$SCAGNOZZ_IP "docker exec prova-db /bin/bash -c 'pg_dump -U prova -d prova_production -F c -f /tmp/$LATEST_BACKUP'"

# Copy the backup file to local machine
echo "Downloading backup file: $LATEST_BACKUP"
ssh root@$SCAGNOZZ_IP "docker cp prova-db:/tmp/$LATEST_BACKUP /tmp/$LATEST_BACKUP"
scp root@$SCAGNOZZ_IP:/tmp/$LATEST_BACKUP ~/backup/new_backup.dmp
ssh root@$SCAGNOZZ_IP "docker exec prova-db rm /tmp/$LATEST_BACKUP && rm /tmp/$LATEST_BACKUP"

echo "Backup completed successfully!"
echo "Backup file saved to: ~/backup/$LATEST_BACKUP"
