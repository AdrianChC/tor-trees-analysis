-- analysis_queries.sql
-- ---------------------------------------------------------------------------
-- Five progressive SQL queries for spatial analysis of NYC neighborhoods
-- and fire hydrants in PostGIS.
--
-- Each query introduces ONE new concept. By Query 5 you're writing
-- spatial SQL fluently — but every step is small and grounded.
--
-- Tables used:
--   nyc_neighborhoods  (262 rows, MultiPolygon, SRID 4326)
--   nyc_hydrants       (109,725 rows, Point, SRID 4326)
--
-- Connection:
--   docker compose exec -e PGPASSWORD=gis postgis \
--     psql -h localhost -U gis -d gis
-- ---------------------------------------------------------------------------


-- =========================================================================
-- QUERY 1: Look at the data (SELECT / FROM / WHERE)
-- =========================================================================
-- Every SQL query is a question you ask a table:
--   SELECT  → which columns do you want?
--   FROM    → which table are they in?
--   WHERE   → which rows do you want?
-- =========================================================================

-- What neighborhoods are in Manhattan?
SELECT
    ntaname,
    boroname
FROM nyc_neighborhoods
WHERE boroname = 'Manhattan'
ORDER BY ntaname;

-- Expected: 38 rows — every neighborhood in Manhattan, alphabetically


-- =========================================================================
-- QUERY 2: Summarize with GROUP BY and COUNT
-- =========================================================================
-- New concept: GROUP BY collapses rows into groups.
-- COUNT(*) tallies each group.
-- Together they answer: "how many of X are in each Y?"
-- =========================================================================

-- How many neighborhoods are in each borough?
SELECT
    boroname,
    COUNT(*) AS neighborhood_count
FROM nyc_neighborhoods
GROUP BY boroname
ORDER BY neighborhood_count DESC;

-- Expected: 5 rows
--    boroname    | neighborhood_count
-- ---------------+--------------------
--  Queens        |                 82
--  Brooklyn      |                 69
--  Bronx         |                 50
--  Manhattan     |                 38
--  Staten Island |                 23


-- =========================================================================
-- QUERY 3: Measure with a spatial function (ST_Area)
-- =========================================================================
-- New concept: spatial functions. ST_Area calculates the area of a polygon.
--
-- Important: our data is in EPSG:4326 (degrees). ST_Area on degrees gives
-- square degrees — meaningless. Casting to ::geography tells PostGIS
-- to calculate in meters instead.
--
-- ntatype = '0' filters to residential neighborhoods (excludes parks,
-- airports, cemeteries).
-- =========================================================================

-- What are the 10 largest residential neighborhoods?
SELECT
    ntaname,
    boroname,
    ROUND(
        (ST_Area(wkb_geometry::geography) / 1000000)::numeric,
        2
    ) AS area_km2
FROM nyc_neighborhoods
WHERE ntatype = '0'
ORDER BY area_km2 DESC
LIMIT 10;

-- Expected: 10 rows — all Staten Island and Queens
--                        ntaname                       |   boroname    | area_km2
-- -----------------------------------------------------+---------------+----------
--  New Springville-Willowbrook-Bulls Head-Travis       | Staten Island |    19.45
--  Todt Hill-Emerson Hill-Lighthouse Hill-Manor Heights| Staten Island |    17.31
--  Annadale-Huguenot-Prince's Bay-Woodrow             | Staten Island |    16.76
--  ...


-- =========================================================================
-- QUERY 4: Spatial join — count hydrants per neighborhood (ST_Contains)
-- =========================================================================
-- New concept: spatial JOIN. Instead of joining on a shared column (like
-- an ID), we join on geometry — "which points fall inside which polygon?"
--
-- ST_Contains(polygon, point) returns true when the point is inside.
-- We LEFT JOIN so neighborhoods with zero hydrants still appear.
-- This is THE pattern for spatial SQL. Every spatial query is a variation.
-- =========================================================================

-- How many hydrants are in each neighborhood?
SELECT
    n.ntaname,
    n.boroname,
    COUNT(h.gid) AS hydrant_count
FROM nyc_neighborhoods n
LEFT JOIN nyc_hydrants h
    ON ST_Contains(n.wkb_geometry, h.wkb_geometry)
WHERE n.ntatype = '0'
GROUP BY n.ntaname, n.boroname
ORDER BY hydrant_count DESC
LIMIT 10;

-- Expected: 10 rows — big outer-borough neighborhoods dominate
--                        ntaname                       |   boroname    | hydrant_count
-- -----------------------------------------------------+---------------+---------------
--  Annadale-Huguenot-Prince's Bay-Woodrow              | Staten Island |          1708
--  Great Kills-Eltingville                             | Staten Island |          1672
--  Todt Hill-Emerson Hill-Lighthouse Hill-Manor Heights| Staten Island |          1282
--  ...
--
-- Notice: Manhattan doesn't appear in the top 10. But is that because
-- Manhattan has fewer hydrants, or because the neighborhoods are smaller?


-- =========================================================================
-- QUERY 5: Density — the spatial insight (combining Query 3 + Query 4)
-- =========================================================================
-- Raw counts are misleading. Big neighborhoods naturally have more of
-- everything. Dividing count by area gives density — a fair comparison.
--
-- This combines what you already know:
--   COUNT(h.gid)                    → from Query 4
--   ST_Area(geometry::geography)    → from Query 3
--   hydrant_count / area            → the new part (just division)
-- =========================================================================

-- Which neighborhoods have the DENSEST hydrant coverage?
SELECT
    n.ntaname,
    n.boroname,
    COUNT(h.gid) AS hydrant_count,
    ROUND(
        (ST_Area(n.wkb_geometry::geography) / 1000000)::numeric,
        2
    ) AS area_km2,
    ROUND(
        COUNT(h.gid) / (ST_Area(n.wkb_geometry::geography) / 1000000)::numeric,
        1
    ) AS hydrants_per_km2
FROM nyc_neighborhoods n
LEFT JOIN nyc_hydrants h
    ON ST_Contains(n.wkb_geometry, h.wkb_geometry)
WHERE n.ntatype = '0'
GROUP BY n.ntaname, n.boroname, n.wkb_geometry
HAVING COUNT(h.gid) > 0
ORDER BY hydrants_per_km2 DESC
LIMIT 10;

-- Expected: 10 rows — ALL Manhattan. The story completely flips.
--                ntaname               | boroname  | hydrant_count | area_km2 | hydrants_per_km2
-- -------------------------------------+-----------+---------------+----------+------------------
--  Gramercy                            | Manhattan |           269 |     0.70 |            384.7
--  SoHo-Little Italy-Hudson Square     | Manhattan |           432 |     1.20 |            360.0
--  Tribeca-Civic Center                | Manhattan |           433 |     1.26 |            343.2
--  West Village                        | Manhattan |           447 |     1.34 |            333.7
--  Financial District-Battery Park City| Manhattan |           570 |     1.79 |            319.1
--  ...
--
-- Same data as Query 4. Completely different story.
-- Staten Island has the MOST hydrants. Manhattan has the DENSEST.
-- Normalization is the honest answer.
