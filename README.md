# NYC Hydrant Density Analysis

## The question

Where is hydrant coverage densest in NYC, and which neighborhoods
are underserved relative to their area?

## The data

- **NYC Neighborhoods:** 262 polygons (Source: NYC Open Data)
- **NYC Fire Hydrants:** 109,725 points (Source: NYC Open Data)
- License: NYC Open Data Terms of Use
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

- Top 5 neighborhoods by hydrant density (per km²):
  1. [Fill in from your results]
  2. ...
- Bottom 5 neighborhoods (least coverage):
  1. ...
- Median neighborhood has X.X hydrants per km².
- Y% of every neighborhood is within 100m of a hydrant.

[Screenshot of the choropleth here]

## How to run it

Requires Docker (for PostGIS) and Python 3.11+ with GeoPandas.

```bash
git clone https://github.com/AdrianChC/nyc-hydrant-analysis.git
cd nyc-hydrant-analysis
```

# Start the PostGIS template from R2.4
docker compose -f docker/postgis/docker-compose.yml up -d

# Load the data, run the SQL pipeline, then the notebook
make load
psql -h localhost -U gisuser -d nyc -f analysis.sql
jupyter lab analysis.ipynb
\`\`\`

## What I learned

[Two or three sentences. Be specific about which step was harder than
expected and what you'd do differently. Do not skip this section.]

## Stack

- PostGIS 16-3.4 (via Docker)
- GeoPandas + SQLAlchemy + matplotlib
- Jupyter Lab
- GeoParquet
