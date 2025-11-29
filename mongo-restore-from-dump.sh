#!/bin/bash
set -euo pipefail

# =====================================================================
# mongo-restore-from-dump.sh
#
# Restore a single MongoDB database on THIS VPS from a mongodump folder.
# This script is meant to be run on the **NEW** VPS (litvps).
#
# ---------------------------------------------------------------------
# PRE-REQUISITES
# ---------------------------------------------------------------------
#
# A) On OLD VPS (EBH-vps) — create the dump
#
#   1) SSH into the old VPS:
#        ssh root@<OLD_VPS_IP>
#
#   2) Create a backup directory:
#        mkdir -p /tmp/mongo-backup
#
#   3) Run mongodump:
#
#      - If there is NO auth on the old Mongo:
#          mongodump --out /tmp/mongo-backup
#
#      - If there IS auth on the old Mongo:
#          mongodump \
#            --host localhost \
#            --port 27017 \
#            -u "OLD_DB_USER" \
#            -p "OLD_DB_PASS" \
#            --authenticationDatabase "admin" \
#            --out /tmp/mongo-backup
#
#      After this, you should have:
#          /tmp/mongo-backup/<SOURCE_DB_NAME>/
#          /tmp/mongo-backup/admin/        (optional, usually ignored)
#
# B) Copy the dump from OLD VPS → NEW VPS
#
#   Run this on the OLD VPS:
#
#       scp -r /tmp/mongo-backup root@<NEW_VPS_IP>:/tmp/
#
#   On the NEW VPS you should now have:
#
#       /tmp/mongo-backup/<SOURCE_DB_NAME>/
#       /tmp/mongo-backup/admin/           (optional)
#
#   Example from your case:
#       /tmp/mongo-backup/EBHDB
#       /tmp/mongo-backup/admin
#
# C) On NEW VPS (litvps) — Mongo + user must exist
#
#   1) MongoDB service is installed and running:
#        sudo systemctl status mongod
#
#   2) A user exists in <AUTH_DB_NAME> with readWrite on <TARGET_DB_NAME>.
#      For your case, something like:
#
#        use T3DB
#        db.createUser({
#          user: "T3AppUser",
#          pwd:  "AppUserPassword123!",
#          roles: [ { role: "readWrite", db: "T3DB" } ]
#        })
#        or use cat /etc/lws-mongo.env to see auth details
#
# ---------------------------------------------------------------------
# USAGE (run on NEW VPS)
# ---------------------------------------------------------------------
#
#   ./mongo-restore-from-dump.sh \
#       <dump_root_dir> \
#       <source_db_name> \
#       <target_db_name> \
#       <auth_db_name> \
#       <db_user> \
#       <db_pass>
#
# Example for your environment:
#
#   ./mongo-restore-from-dump.sh \
#       /tmp/mongo-backup \
#       EBHDB \
#       T3DB \
#       T3DB \
#       T3AppUser \
#       'AppUserPassword123!'
#
# This will:
#   - Connect to Mongo on localhost:27017
#   - Authenticate as T3AppUser against T3DB
#   - DROP existing collections in T3DB
#   - Restore data from /tmp/mongo-backup/EBHDB into T3DB
#
# =====================================================================

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <dump_root_dir> <source_db_name> <target_db_name> <auth_db_name> <db_user> <db_pass>"
  exit 1
fi

DUMP_ROOT="$1"
SRC_DB="$2"
TARGET_DB="$3"
AUTH_DB="$4"
DB_USER="$5"
DB_PASS="$6"

HOST="localhost"
PORT="${MONGO_PORT:-27017}"

DUMP_PATH="$DUMP_ROOT/$SRC_DB"

if [ ! -d "$DUMP_PATH" ]; then
  echo "❌ Error: dump directory '$DUMP_PATH' not found."
  echo "Make sure mongodump created '$SRC_DB' inside '$DUMP_ROOT'."
  exit 1
fi

echo "============================================"
echo " MongoDB Restore"
echo "--------------------------------------------"
echo " Host:        $HOST"
echo " Port:        $PORT"
echo " Source dump: $DUMP_PATH"
echo " Target DB:   $TARGET_DB"
echo " Auth DB:     $AUTH_DB"
echo " User:        $DB_USER"
echo "============================================"
echo

mongorestore \
  --host "$HOST" \
  --port "$PORT" \
  -u "$DB_USER" \
  -p "$DB_PASS" \
  --authenticationDatabase "$AUTH_DB" \
  --db "$TARGET_DB" \
  --drop \
  "$DUMP_PATH"

echo
echo "✅ Restore complete for DB '$TARGET_DB'."
