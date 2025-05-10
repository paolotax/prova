#!/bin/bash

# Rimuove i vecchi file di backup
rm ~/backup/backup.*

# Copia il file di backup dal server remoto
scp root@116.203.224.90:backup.tar.gz ~/backup/

# Crea un nuovo archivio tar con i permessi originali
tar -xzvf ~/backup/backup.tar.gz -C ~/backup/