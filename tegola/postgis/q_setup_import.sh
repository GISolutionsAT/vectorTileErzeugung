#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER tegola WITH PASSWORD 'password';
	CREATE DATABASE borders template=template_postgis;

EOSQL

ogr2ogr -f "PostgreSQL" PG:"dbname=borders user=postgres" "/data/covid19_austria.geojson" -nln austriaborder -overwrite
ogr2ogr -f "PostgreSQL" PG:"dbname=borders user=postgres" "/data/covid19_district.geojson" -nln districtsborder -overwrite

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "borders" <<-EOSQL
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO tegola;

EOSQL
