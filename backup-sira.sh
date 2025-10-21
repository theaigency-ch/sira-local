#!/bin/bash
# Sira Backup Script
# Erstellt Backups von Redis, Qdrant und Data-Verzeichnis

BACKUP_DIR="/backups/sira"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$DATE"

echo "🔄 Starte Sira Backup: $DATE"

# Erstelle Backup-Verzeichnis
mkdir -p "$BACKUP_PATH"

# 1. Redis Backup
echo "📦 Sichere Redis..."
docker exec redis-sira redis-cli --pass DohajERz0wlqQiIqzrMuJtVlKxxlSQA71aYYHeU1t2w BGSAVE
sleep 2
docker cp redis-sira:/data/dump.rdb "$BACKUP_PATH/redis-dump.rdb"

# 2. Qdrant Backup (Snapshots)
echo "📦 Sichere Qdrant Collections..."
# Sira Memory Collection
curl -X POST "http://localhost:6333/collections/sira_memory/snapshots" \
  -H "Content-Type: application/json" \
  -d '{}'
  
# Sira Facts Collection  
curl -X POST "http://localhost:6333/collections/sira_facts/snapshots" \
  -H "Content-Type: application/json" \
  -d '{}'

# Warte auf Snapshot-Erstellung
sleep 5

# Kopiere Qdrant Storage
docker cp qdrant:/qdrant/storage "$BACKUP_PATH/qdrant-storage"

# 3. Data-Verzeichnis (Icons, etc.)
echo "📦 Sichere Data-Verzeichnis..."
cp -r ./data "$BACKUP_PATH/data" 2>/dev/null || true

# 4. Erstelle Archiv
echo "🗜️ Erstelle Archiv..."
cd "$BACKUP_DIR"
tar -czf "sira-backup-$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

# 5. Lösche alte Backups (älter als 7 Tage)
echo "🗑️ Lösche alte Backups..."
find "$BACKUP_DIR" -name "sira-backup-*.tar.gz" -type f -mtime +7 -delete

echo "✅ Backup abgeschlossen: $BACKUP_DIR/sira-backup-$DATE.tar.gz"

# Zeige Backup-Größe
ls -lh "$BACKUP_DIR/sira-backup-$DATE.tar.gz"

# Optional: Upload zu S3/Google Drive
# aws s3 cp "$BACKUP_DIR/sira-backup-$DATE.tar.gz" s3://your-bucket/sira-backups/
# rclone copy "$BACKUP_DIR/sira-backup-$DATE.tar.gz" gdrive:sira-backups/
