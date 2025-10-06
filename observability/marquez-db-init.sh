#!/usr/bin/env sh
set -Eeuo pipefail

# defaults if env vars are unset/empty
: "${PGHOST:=postgresdb}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGPASSWORD:=postgres}"
: "${MARQUEZ_DB:=marquez}"
: "${MARQUEZ_DB_USER:=marquez}"
: "${MARQUEZ_DB_PASSWORD:=marquez}"
: "${MARQUEZ_DB_RESET:=false}"

export PGPASSWORD

echo "[init] PGHOST=$PGHOST PGPORT=$PGPORT PGUSER=$PGUSER"
echo "[init] DB=$MARQUEZ_DB USER=$MARQUEZ_DB_USER (password hidden)"

until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
  echo "[init] waiting for postgres at $PGHOST:$PGPORT ..."
  sleep 2
done
echo "[init] connected."

if [ "$MARQUEZ_DB_RESET" = "true" ]; then
  echo "[init] resetting database $MARQUEZ_DB"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${MARQUEZ_DB}'"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres \
    -c "DROP DATABASE IF EXISTS \"${MARQUEZ_DB}\""
fi

# create role if missing
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -Atqc \
  "SELECT 1 FROM pg_roles WHERE rolname='${MARQUEZ_DB_USER}'" | grep -q 1 ||
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c \
  "CREATE ROLE \"${MARQUEZ_DB_USER}\" LOGIN PASSWORD '${MARQUEZ_DB_PASSWORD}'"

# create db if missing
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -Atqc \
  "SELECT 1 FROM pg_database WHERE datname='${MARQUEZ_DB}'" | grep -q 1 ||
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c \
  "CREATE DATABASE \"${MARQUEZ_DB}\" OWNER \"${MARQUEZ_DB_USER}\" ENCODING 'UTF8'"

# ownership + schema grants
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "${MARQUEZ_DB}" -c \
  "ALTER DATABASE \"${MARQUEZ_DB}\" OWNER TO \"${MARQUEZ_DB_USER}\""
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "${MARQUEZ_DB}" -c \
  "ALTER SCHEMA public OWNER TO \"${MARQUEZ_DB_USER}\"; GRANT ALL ON SCHEMA public TO \"${MARQUEZ_DB_USER}\""
