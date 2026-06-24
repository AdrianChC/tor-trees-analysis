# Lesson 2.2: PostGIS Setup & Data Loading

### Goal

Install a PostGIS database on Docker. [More info](https://postgis.net/documentation/getting_started/install_docker/)

### What you'll build

A local PostGIS database loaded with two NYC spatial datasets - neighborhoods and fire hydrants - ready for SQL analysis in the next lesson.# pulls the pre-built PostGIS image from Kartoza's public repository

### Prerequisites
- [ ] Docker Desktop installed and running (docker --version)
- [ ] Enable Docker Desktop WSL integration (not with the docker-desktop distro)

    **Step 1**. Oepn Docker Desktop (Windows)

    Go to: Settings -> Resources -> WSL Integration

    **Step 2**. Enable Ubuntu distro

    **Turn ON**:
        
    ✅ Enable integration with my default WSL distro
        
    Enable integration with additional distros
        
    ✅ Ubuntu

- [ ] GDAL installed (ogr2ogr --version)
- [ ] Terminal open in 2.2-postgis-setup

### Setup

#### Software:

- Docker Desktop installed and running (verify with `docker compose version`)
- To create the right pixi environment 
    1. Create a new env. Run `pixi init` in the project folder
    2. Install libraries. Run `pixi add gdal libgdal postgresql`
    - `gdal`: the gdal command-line utilities like `ogr2ogr`, `ogrinfo`
    - `libgdal`: the core GDAL library that contains drivers (GeoJSON, PostGIS), projections, geometry, raster + vector processing engine
    - `postgresql`: provides the PostgreSQL ecosystem `psql`, PostgreSQL client libraries, database connection utilities
- GDAL/ORG installed (verify with `ogr2ogr --version`)
- Verify that PostgreSQL driver is available (use `ogr2ogr --formats | grep -i postgres`)
- Should list `PostgreSQL -vector- (rw+u): PostgreSQL/PostGIS`

**Files**: All files for this excercise are in part2-languages/2.2-postgis-setup/:

- `docker-compose.yml` -- PostGIS container configuration
- `load_data.sh` -- downloads data and loads it into PostGIS
- `load_data.sql` -- verification queries

-------

### Steps

#### Step 1: Start the PostGIS container

Docker Compose reads the `docker-compose.yml` file and starts a PostgreSQL database with the PostGIS spatial extension pre-installed.

    cd part2-languages/2.2-postgis.setup/   
    docker compose up -d

Verify: 

    docker compose ps 

You should see `gis_postgis` with status "Up" or "Running".

Also, you could verify on Docker Desktop GUI. Volumes -> Active

#### Step 2: Verify PostGIS is working

Connect to the database and check that PostGIS is installed.

    docker compose exec -e PGPASSWORD=gis postgis psql -h localhost -U gis -d gis -c "SELECT PostGIS_Version();"

You should see: A version string like `3.6 USE_GEOS=1 USE_PROJ=1 USE_STATS=1` (numbers may differ)

#### Step 3: Download data and load into PostGIS

The `load_data.sh` script download two datasets from NYC Open Data and loads them into PostGIS usign `ogr2ogr`. GDAL is writing into a database instead of a file.

    bash load_data.sh

Expect the script prints progress for each step.

