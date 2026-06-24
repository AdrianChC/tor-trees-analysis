#!/usr/bin/env bash
# load_data.sh
# ---------------------------------------------------------------------------
# Downloads City of Toronto Open Data SHP file, turn it into GeoJSON files
# and loads them into PostGIS using # ogr2ogr (part of GDAL).
#
# Inputs:   None — downloads data from City of Toronto's CKAN open-data portal.
# Outputs:  Two PostGIS tables in the "gis" database:
#           - tor_neighborhoods (~158 rows, MultiPolygon, EPSG:4326)
#           - tor_trees         (~1,249,665 rows, Point, EPSG:4326)
#
# Prerequisites:
#   - Docker container "tor_gis_postgis" running (docker compose up -d)
#   - GDAL installed (ogr2ogr --version to check)
#
# Usage:    bash load_data.sh
# ---------------------------------------------------------------------------

set -e  # Stop on first error so students see exactly which step failed

# --- Configuration --------------------------------------------------------
DATA_DIR="./data/raw"
PG="PG:host=localhost port=5432 dbname=gis user=gis password=gis"

# Toronto CKAN Open Data links
TORN_URL="https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/5e7a8234-f805-43ac-820f-03d7c360b588/resource/737b29e0-8329-4260-b6af-21555ab24f28/download/City%20Wards%20Data%20-%204326.geojson"
TREE_URL="https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/84f16008-8040-40ba-844d-c1d3863b80f6/resource/16f63d08-22e3-4957-a6b9-f78bf2af46da/download/tree_wgs84.zip"

# --- Create data directory ------------------------------------------------
mkdir -p "$DATA_DIR"
echo "📁 Data directory ready: $DATA_DIR"

# --- Download neighborhoods GeoJSON file -----------------------------------
echo ""
echo "⬇️  Downloading TOR Neighborhoods (158 )..."
curl -L -o "$DATA_DIR/tor_neighborhoods.geojson" "$TORN_URL"

# Quick check — file should be more than 1 KB
FILE_SIZE=$(wc -c < "$DATA_DIR/tor_neighborhoods.geojson" | tr -d ' ')
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "❌ ERROR: neighborhoods file is only $FILE_SIZE bytes — download may have failed."
    echo "   Check the URL or your internet connection."
    exit 1
fi
echo "✅ Downloaded tor_neighborhoods.geojson ($FILE_SIZE bytes)"

# --- Download trees ZIP file -------------------------------------------------
echo ""
echo "⬇️  Downloading TOR trees points (this may take a minute — ~1.25M records)..."
curl -L -o "$DATA_DIR/tor_trees.zip" "$TREE_URL"

FILE_SIZE=$(wc -c < "$DATA_DIR/tor_trees.zip" | tr -d ' ')
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "❌ ERROR: trees file is only $FILE_SIZE bytes — download may have failed."
    echo "   Check the URL or your internet connection."
    exit 1
fi
echo "✅ Downloaded tor_trees.zip ($FILE_SIZE bytes)"

# --- Create neighborhoods GeoJSON file --------------------------------------
INPUT_ZIP="$DATA_DIR/tor_trees.zip"
OUTPUT_GEOJSON="$DATA_DIR/tor_trees.geojson"

## temp working directory
TMP_DIR=$(mktemp -d)

echo ""
echo "📦 Unzipping TOR trees file"
unzip -q "$INPUT_ZIP" -d "$TMP_DIR"

## find the .shp file inside the extracted folder
SHP_FILE=$(find "$TMP_DIR" -name "*.shp" | head -n 1)

if [ -z "$SHP_FILE" ]; then
  echo "Error: No .shp file found in ZIP"
  exit 1
fi

## convert .shp to .geojson
echo "🔄 Converting to GeoJSON format"

ogr2ogr -f GeoJSON "$OUTPUT_GEOJSON" "$SHP_FILE"

FILE_SIZE=$(wc -c < "$DATA_DIR/tor_trees.geojson" | tr -d ' ')

echo "✅ Created tor_trees.geojson ($FILE_SIZE bytes)"

# cleanup
rm -rf "$TMP_DIR"
rm -rf "$INPUT_ZIP"


# --- Wait for PostGIS to be ready -----------------------------------------
echo ""
echo "⏳ Checking PostGIS connection..."
for i in $(seq 1 10); do
    if docker compose exec -T -e PGPASSWORD=gis postgis pg_isready -h localhost -U gis -d gis > /dev/null 2>&1; then
        echo "✅ PostGIS is ready"
        break
    fi
    if [ "$i" -eq 10 ]; then
        echo "❌ ERROR: Could not connect to PostGIS after 10 attempts."
        echo "   Make sure the container is running: docker compose up -d"
        exit 1
    fi
    echo "   Waiting for PostGIS... (attempt $i/10)"
    sleep 3
done

# --- Load neighborhoods into PostGIS --------------------------------------
echo ""
echo "📤 Loading neighborhoods into PostGIS..."
# -nln        = set the table name
# -lco        = layer creation options
# -overwrite  = replace table if it already exists (safe for re-runs)
# -s_srs/-t_srs = source and target coordinate systems (both WGS84)
ogr2ogr \
    -f "PostgreSQL" \
    "$PG" \
    "$DATA_DIR/tor_neighborhoods.geojson" \
    -nln tor_neighborhoods \
    -overwrite \
    -lco GEOMETRY_NAME=wkb_geometry \
    -lco FID=gid \
    -t_srs EPSG:4326

 echo "✅ Loaded tor_neighborhoods table"
 
# --- Load trees into PostGIS -------------------------------------------
echo ""
echo "📤 Loading trees into PostGIS (this may take a moment)..."
ogr2ogr \
    -f "PostgreSQL" \
    "$PG" \
    "$DATA_DIR/tor_trees.geojson" \
    -nln tor_trees \
    -overwrite \
    -lco GEOMETRY_NAME=wkb_geometry \
    -lco FID=gid \
    -t_srs EPSG:4326

echo "✅ Loaded tor_trees table"

# --- Verify ---------------------------------------------------------------
echo ""
echo "🔍 Verifying loaded data..."
echo ""

echo "--- Neighborhood count ---"
docker compose exec -T -e PGPASSWORD=gis postgis psql -h localhost -U gis -d gis -c \
    "SELECT COUNT(*) AS neighborhood_count FROM tor_neighborhoods;"

echo ""
echo "--- Trees count ---"
docker compose exec -T -e PGPASSWORD=gis postgis psql -h localhost -U gis -d gis -c \
    "SELECT COUNT(*) AS trees_count FROM tor_trees;"

echo ""
echo "--- Geometry columns ---"
docker compose exec -T -e PGPASSWORD=gis postgis psql -h localhost -U gis -d gis -c \
    "SELECT f_table_name, type, srid FROM geometry_columns ORDER BY f_table_name;"

echo ""
echo "🎉 All done! Your PostGIS database is loaded and ready."
echo "   Connect with: psql -h localhost -U gis -d gis"
echo "   Or use DBeaver/pgAdmin at localhost:5432"
