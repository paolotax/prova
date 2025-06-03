#!/bin/bash

# Configurazioni
CONTAINER_NAME="prova-db-1"
DB_NAME="prova_development"
DB_USER="prova"
DUMP_PATH_ON_HOST="/home/paolotax/backup/new_backup.dmp"
DUMP_PATH_IN_CONTAINER="/tmp/new_backup.dmp"

# 1. Drop e ricrea il database
echo "👉 Dropping database $DB_NAME (se esiste)..."
docker exec -i $CONTAINER_NAME psql -U prova -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"

echo "✅ Database droppato. Ora lo ricreo con owner $DB_USER..."
docker exec -i $CONTAINER_NAME psql -U prova -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER;"

# 2. Copia il file .dmp nel container
echo "📦 Copio il dump nel container..."
docker cp "$DUMP_PATH_ON_HOST" "$CONTAINER_NAME:$DUMP_PATH_IN_CONTAINER"

# 3. Restore con pg_restore
echo "♻️ Lancio pg_restore sul DB $DB_NAME..."
docker exec -i $CONTAINER_NAME pg_restore -U prova -d $DB_NAME -O "$DUMP_PATH_IN_CONTAINER"

echo "🎉 Restore completato!"
