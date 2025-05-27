#!/bin/bash

# Create backup directory if it doesn't exist
mkdir -p ~/backup

# Get the latest backup file from the container
echo "Executing backup in production container..."
ssh root@116.203.224.90 "docker exec prova-db /bin/bash -c 'pg_dump -U prova -d prova_production -F c -f /tmp/backup_$(date +%Y%m%d_%H%M%S).dump'"

# Get the latest backup file
LATEST_BACKUP=$(ssh root@116.203.224.90 "docker exec prova-db ls -t /tmp | head -n1")

# Copy the backup file to local machine
echo "Downloading backup file: $LATEST_BACKUP"
ssh root@116.203.224.90 "docker cp prova-db:/tmp/$LATEST_BACKUP /tmp/$LATEST_BACKUP"
scp root@116.203.224.90:/tmp/$LATEST_BACKUP ~/backup/
ssh root@116.203.224.90 "rm /tmp/$LATEST_BACKUP"

echo "Backup completed successfully!"
echo "Backup file saved to: ~/backup/$LATEST_BACKUP"