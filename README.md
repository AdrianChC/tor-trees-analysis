# Toronto Tree Density Analysis

## The question

Where is tree coverage densest in Toronto, and which neighborhoods
are underserved relative to their area?

## The data

- **Toronto Neighborhoods:** 158 polygons (Source: City of Toronto Open Data)
- **Toronto Trees:** 1,249,665 points (Source: City of Toronto Open Data)
- License: City of Toronto Open Data Terms of Use
- All data in EPSG:4326

## Methodology

Built the same analysis twice:

- **SQL (PostGIS):** five progressive queries in `analysis.sql`, going
  from simple filter to spatial join to area-normalized density to
  100m-buffer coverage analysis.
- **Python (GeoPandas):** equivalent pipeline in `analysis.ipynb`,
  with a static choropleth and interactive `.explore()` map. Final
  output exported to GeoParquet.

Both pipelines produce the same density values to within rounding.
The Python version is the one that produces the visualization; the SQL
version is the one that runs against a database at scale.

## Findings

- Top 5 neighborhoods by tree density (per km²):
  1. The highest tree density neighborhood is Bridle Path-Sunnybrook-York Mills. It has 3,042.65 trees per km².
  2. The other neighborhoods in the top 5 are located
  one or two neighborhoods afar from Path-Sunnybrook-York Mills
  3. Guildwood is the only one located fairly distant to the rest.
- Bottom 5 neighborhoods (least coverage):
  1. The lowest tree density neighborhood is Yonge-Bay Corridor.
  It has 337.5 trees per km².
  2. The other neighborhoods in the bottom 5 are located
  next to Yonge-Bay Corridor.
  3. Etibocke City Centre is the only one located 
  fairly distant to the rest.
- The median neighborhood has 2,008.24 trees per km².
- On averange a neighborhood has 1,951.75 trees per km².
- Tree Coverage (percentage):
  1. The tree coverage percentage is consistently high. 
  2. 77 Neighborhoods out of 158 have 100% coverage. 
  3. 154 Neighborhoods out of 158 have coverage above 90%.
  4. The lowest tree coverage percentage neighborhood is St. Lawrence-East Bayfront- The Islands. It has 52.61% coverage.
- The median neighborhood has 99.84% tree coverage percentage.
- On averange a neighborhood has 98.6% tree coverage percentage.

## How to run it

Requires Docker (for PostGIS) and Python 3.11+ with GeoPandas.

```bash
git clone https://github.com/AdrianChC/tor-tree-analysis.git
cd tor-tree-analysis
```

# Set project environment
  make env

# Start the PostGIS volume
  make set-docker

More detail information in `setup-postgis.md`

# Load the data
  make load-data

# Run the analysis with SQL
Run each query independently. Follow the pattern to execute each query:
  docker compose exec -T -e PGPASSWORD=gis postgis psql -h localhost -U gis -d gis -c \
  "
  Copy QUERY here
  "

# Set and run the analysis with Jupyter Notebook
Set kernel from this project environment
  make set-kernel

Open `analysis.ipynb` and run the code to calculate each result, plots, and return a geoparquet file.

## What I learned

- Setting up a remote environment with Windows Subsystem for Linux (WSL) was challenging.
- Installing the libraries in the right order was key to make every process work seamlessly.
- Set up a reproducible project environment that allows running
the ETL pipeline, SQL and Jupyter Notebook.
- Set up a ETL pipeline from a data portal that delivers ready-to-use data.
- Prepared a Jupyter Notebook with basic spatial EDA that reports two spatial metrics 
and visualize them with maps.
- The hardest part was setting up the project environment, making it reproducible, and
easy to use. 
- Creating a Makefile is useful for simplifying the project setup.
- To improve this project, I would try to encapsulate everything in a Docker container.
- It is interesting to note that SQL queries are much more efficient than Python scripts.
- Achieving the same results required less code in SQL than Python.

## Stack

- PostGIS 16-3.4 (via Docker) + GDAL
- GeoPandas + matplotlib
- Jupyter Lab
- GeoParquet
