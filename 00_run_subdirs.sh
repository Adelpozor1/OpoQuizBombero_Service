#!/bin/bash
# Postgres solo procesa ficheros del nivel superior de /docker-entrypoint-initdb.d.
# Este shim ejecuta los .sql de los subdirectorios en orden alfabetico
# (1-migrations, 2-seeds, 3-sql = procedimientos almacenados).
set -e

for dir in /docker-entrypoint-initdb.d/1-migrations /docker-entrypoint-initdb.d/2-seeds /docker-entrypoint-initdb.d/3-sql; do
  if [ -d "$dir" ]; then
    for f in $(ls -1 "$dir"/*.sql 2>/dev/null | sort); do
      echo "shim: running $f"
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
    done
  fi
done
