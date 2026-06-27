-- analysis_queries.sql
-- ---------------------------------------------------------------------------
-- Five progressive SQL queries for spatial analysis of Toronto neighborhoods
-- and trees in PostGIS. Each query introduces ONE new concept.
--
-- Tables used:
--   tor_neighborhoods  (25 rows, MultiPolygon, SRID 4326)
--   tor_hydrants       (1,249,665 rows, Point, SRID 4326)
--
-- Connection:
--   docker compose exec -e PGPASSWORD=gis postgis \
--     psql -h localhost -U gis -d gis
-- ---------------------------------------------------------------------------

-- =========================================================================
-- Create Spatial Indexes for Data Tables
-- =========================================================================
-- New concepts: 
--   Spatial Indexes speed up spatial queries by organizing geometries
--   into a search tree based on their bounding boxex.

--   Bounding boxes are used to quickly filter out non-matching 
--   geometries before performing more expensive spatial comparisons

--   CREATE INDEX   → what's the name of the spatial index?
--   ON             → which table is the spatial index on?
--   USING          → what is the type of spatial index?
-- =========================================================================

-- Neighborhoods Table Spatial Index
CREATE INDEX 
    idx_neighborhoods_geom
ON 
    tor_neighborhoods
USING 
    GIST (wkb_geometry);

-- Trees Table Spatial Index
CREATE INDEX 
    idx_trees_geom
ON 
    tor_trees
USING 
    GIST (wkb_geometry);


-- =========================================================================
-- QUERY 1: What neighborhoods are in Toronto? 
-- =========================================================================
-- Every SQL query is a question you ask a table:
--   SELECT  → which columns do you want?
--   FROM    → which table are they in?
--   WHERE   → which rows do you want?
-- =========================================================================

-- Look at the data (SELECT / FROM / WHERE)
SELECT
    AREA_NAME,
    AREA_SHORT_CODE
FROM tor_neighborhoods
ORDER BY AREA_NAME;

-- Expected: 158 rows — every neighborhood in Toronto, alphabetically


-- =========================================================================
-- QUERY 2: How many trees are in the neighborhoods?
-- =========================================================================
-- New concepts: 
--   LEFT JOIN joins tables a to b based ON a join condition.
--   ST_Contains(polygon, point) returns TRUE when the point is inside. 
-- Together they answer: "which of X are in each Y?"
--
-- This is THE pattern for spatial SQL. Every spatial query is a variation.
-- =========================================================================

-- Matches each tree to its neighborhood (ST_Contains)
SELECT
    t.gid AS tree_id,
    n.AREA_NAME as neighborhood    
FROM tor_neighborhoods n
LEFT JOIN tor_trees t
    ON ST_Contains(n.wkb_geometry, t.wkb_geometry)
LIMIT 5 

-- Expected: 5 rows (~1,249,665 rows without LIMIT)
--  tree_id |       neighborhood        
-- ---------+---------------------------
--   298088 | South Eglinton-Davisville
--  1141535 | South Eglinton-Davisville
--   297315 | South Eglinton-Davisville
--   297314 | South Eglinton-Davisville
--   300705 | South Eglinton-Davisville
--  ...


-- =========================================================================
-- QUERY 3: How many trees are in each neighborhood?
-- =========================================================================
-- New concept: 
--   GROUP BY collapses rows into groups.
--   COUNT(t.gid) tallies each group.
-- Together they answer: "how many of X are in each Y?"
-- =========================================================================

-- Summarize trees by neighborhood (GROUP BY and COUNT)
SELECT
    n.AREA_NAME as neighborhood,
    COUNT(t.gid) AS tree_count
FROM tor_neighborhoods n
LEFT JOIN tor_trees t
    ON ST_Contains(n.wkb_geometry, t.wkb_geometry)
GROUP BY n.AREA_NAME
ORDER BY tree_count DESC
LIMIT 158 

-- Expected: 158 rows
--            neighborhood            | tree_count 
-- -----------------------------------+------------
--  Morningside Heights               |      67512
--  West Humber-Clairville            |      28538
--  Bridle Path-Sunnybrook-York Mills |      26897


-- =========================================================================
-- QUERY 4: Which neighborhoods have the DENSEST tree per km²?
-- =========================================================================
-- Raw counts are misleading. Big neighborhoods naturally have more of
-- everything. Dividing count by area gives density — a fair comparison.
-- This process is called normalization. It adjust raw counts or value 
-- relative to another variable making comparisons fair.
--
-- New concept: 
--   spatial functions. ST_Area calculates the area of a polygon.
--
-- Important: 
--   The data is in EPSG:4326 (degrees). 
--   ST_Area on degrees gives square degrees — meaningless. 
--   Casting to ::geography tells PostGIS to calculate in meters instead.
--
-- This combines:
--   COUNT(t.gid)                   → from Query 3
--   ST_Area(geometry::geography)   → from Query 4
-- =========================================================================

-- Calculating Tree Density to compare results (COUNT + ST_Area)
SELECT
    n.AREA_NAME as neighborhood,
    COUNT(t.gid) AS tree_count,
    ROUND(
        (ST_Area(n.wkb_geometry::geography) / 1000000)::numeric,
        2
    ) AS area_km2,
    ROUND(
        COUNT(t.gid) / (ST_Area(n.wkb_geometry::geography) / 1000000)::numeric,
        2
    ) AS trees_per_km2
FROM tor_neighborhoods n
LEFT JOIN tor_trees t
    ON ST_Contains(n.wkb_geometry, t.wkb_geometry)
GROUP BY n.AREA_NAME, n.wkb_geometry
HAVING COUNT(t.gid) > 0
ORDER BY trees_per_km2 DESC
LIMIT 158; 

--              neighborhood              | tree_count | area_km2 | trees_per_km2 
-- ---------------------------------------+------------+----------+---------------
--  Bridle Path-Sunnybrook-York Mills     |      26897 |     8.84 |       3041.71
--  Lansing-Westgate                      |      16018 |     5.35 |       2994.89
--  ...
--  Wellington Place                      |        448 |     0.98 |        457.13
--  Yonge-Bay Corridor                    |        378 |     1.12 |        337.76


-- =========================================================================
-- QUERY 5: Which neighborhoods have the highest coverage within 100 meters?
-- =========================================================================
-- Coverage analysis leads to a deeper finding by aggregating buffer areas
-- of 100 m from each tree.  
--
-- New concept: 
--   Buffer. ST_Buffer calculates the area within a point given a radius.
--   Union. ST_Union merges geometries into a single one with no overlaps.
--   Intersection. ST_Intersection returns the shared area of A and B.
--   Common Table Expresion (CTE). Calculate values once, call them later.
-- =========================================================================

-- Coverage Analysis (ST_Buffer + ST_Union + ST_Intersection)
WITH analysis AS (
    SELECT
        n.AREA_NAME as neighborhood,
        ST_Area(n.wkb_geometry :: geography) / 1000000 AS n_area,
        ST_Area(
            ST_Intersection(
                (ST_Union(
                    (ST_Buffer(t.wkb_geometry :: geography, 100) :: geometry)
                ) :: geography),
                n.wkb_geometry :: geography
            )
        ) / 1000000 AS t_area
    FROM
        tor_trees t
    JOIN
        tor_neighborhoods n
    ON 
        ST_Intersects(t.wkb_geometry, n.wkb_geometry)
    GROUP BY 
        n.AREA_NAME, n.wkb_geometry
)

SELECT
    neighborhood,
    ROUND(n_area :: numeric, 2) AS area_km2,
    ROUND(t_area :: numeric, 2) AS tree_coverage_area_km2,
    ROUND((100 * t_area / n_area) ::numeric, 2) AS coverage_percentage    
FROM
    analysis
ORDER BY
    coverage_percentage DESC
LIMIT 158;

--              neighborhood              | area_km2 | tree_coverage_area_km2 | coverage_percentage 
-- ---------------------------------------+----------+------------------------+---------------------
--  Caledonia-Fairbank                    |     1.55 |                   1.55 |              100.00
--  Edenbridge-Humber Valley              |     5.51 |                   5.51 |              100.00
--  ...
--  Downsview                             |     8.29 |                   6.34 |               76.46
--  St Lawrence-East Bayfront-The Islands |    11.32 |                   5.95 |               52.55