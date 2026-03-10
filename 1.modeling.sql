-- 00_reset.sql
-- 0) Reset raw.m_1 schema by respecting the exact column order as shown in the csv file 
DROP TABLE IF EXISTS raw.m_1;

CREATE TABLE raw.m_1 (
  "Brand" text,
  "Name" text,
  "Category" text,
  "SKU" text,
  "URL" text,
  "Collection" text,
  "Switzerland" text,
  "France" text,
  "USA" text,
  "China" text,
  "Hong Kong" text,
  "Japan" text,
  "Singapore" text,
  "UAE" text,
  "United Kingdom" text,
  "South Korea" text
);
-- 1) reset / create schemas / check column names
CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.m;
CREATE TABLE raw.m (LIKE raw.m_1 INCLUDING ALL);
ALTER TABLE raw.m DROP COLUMN "URL"; 

-- Check column names (sanity)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'raw' AND table_name = 'm';
-- 2) create canonical tables
DROP TABLE IF EXISTS raw.sales_wide;

CREATE TABLE raw.sales_wide (
		month_order INT,
		month_label TEXT, 
		brand TEXT,
		name TEXT,
		category TEXT,
		sku TEXT,
		url TEXT,
		collection TEXT,
		switzerland NUMERIC,
		france NUMERIC,
		usa NUMERIC,
		china NUMERIC,
		"Hong Kong" NUMERIC,
		japan NUMERIC,
		singapore NUMERIC,
		uae NUMERIC,
		"United Kingdom" NUMERIC,
		"South Korea" NUMERIC
);
-- 3) load canonical tables
TRUNCATE TABLE raw.sales_wide;

-- Insert M-1 (raw.m_1 has URL)
INSERT INTO raw.sales_wide (
	month_order, month_label,
	brand, name, category, sku, url,collection,
	switzerland, france, usa, china, "Hong Kong", japan, singapore, uae, "United Kingdom", "South Korea"
)
SELECT 
	0 		AS month_order,
	'M-1' 	AS month_label,
	"Brand" AS brand,
	"Name"  AS name,
	"Category"  AS category,
	"SKU"       AS sku,
	"URL"       AS url,
	"Collection" AS collection,
	
	NULLIF("Switzerland", '')::numeric,
	NULLIF("France",'')::numeric,
	NULLIF("USA",'')::numeric,
	NULLIF("China",'')::numeric,
	NULLIF("Hong Kong",'')::numeric,
	NULLIF("Japan",'')::numeric,
	NULLIF("Singapore",'')::numeric,
	NULLIF("UAE",'')::numeric,
	NULLIF("United Kingdom",'')::numeric,
	NULLIF("South Korea",'')::numeric
FROM raw.m_1;

 -- Insert M (raw.m has no URL)
INSERT INTO raw.sales_wide (
month_order, month_label,
brand, name, category, sku, url,collection,
switzerland, france, usa, china, "Hong Kong", japan, singapore, uae, "United Kingdom", "South Korea"
)
SELECT 
	1 AS month_order,
	'M' AS month_label,
	"Brand"     AS brand,
	"Name"      AS name,
	"Category"  AS category,
	"SKU"       AS sku,
	NULL::text AS url, -- Fill url with null 
	"Collection" AS collection,
	
	NULLIF("Switzerland", '')::numeric,
	NULLIF("France",'')::numeric,
	NULLIF("USA",'')::numeric,
	NULLIF("China",'')::numeric,
	NULLIF("Hong Kong",'')::numeric,
	NULLIF("Japan",'')::numeric,
	NULLIF("Singapore",'')::numeric,
	NULLIF("UAE",'')::numeric,
	NULLIF("United Kingdom",'')::numeric,
	NULLIF("South Korea",'')::numeric
FROM raw.m;

-- 4) Audits on `raw.sales_wide`
-- 4.1) Key audits: is SKU present? how many distinct? duplicates?
SELECT 
	COUNT(*) AS rows_total,
	SUM(CASE WHEN sku IS NULL OR btrim(sku) = '' THEN 1 ELSE 0 END) AS sku_null,
	COUNT(DISTINCT sku) AS distinct_skus
FROM raw.sales_wide 
GROUP BY month_label;

SELECT 
	month_label, 
	sku, 
	COUNT(*) AS number
FROM raw.sales_wide 
GROUP BY month_label, sku 
HAVING COUNT(*) > 1
ORDER BY number DESC, month_label, sku;

-- 4.2) 1NF check: detect multiple-SKUs cell -> Need to split rows
SELECT 
	month_label,
	COUNT(*) AS multiple_sku_rows
FROM raw.sales_wide
WHERE sku LIKE '%;%'
GROUP BY month_label
ORDER BY month_label;

SELECT 
	month_label,
	sku
FROM raw.sales_wide
WHERE sku LIKE '%;%';

-- 4.3) Functional dependency check: (SKU → Brand/Name/Category/Collection/URL) 
SELECT 
	month_label,
	sku,
	COUNT(DISTINCT brand) AS n_brand,
	COUNT(DISTINCT name) AS n_name,
	COUNT(DISTINCT category) AS n_category,
	COUNT(DISTINCT collection) AS n_collection,
	COUNT(DISTINCT url) AS n_url
FROM raw.sales_wide
WHERE sku IS NOT NULL AND btrim(sku) <> ''
GROUP BY month_label, sku  -- to produce the same effect as in pandas version
HAVING 	COUNT(DISTINCT brand) > 1 
		OR COUNT(DISTINCT name) > 1 
		OR COUNT(DISTINCT url) > 1  
		OR COUNT(DISTINCT category) > 1 
		OR COUNT(DISTINCT collection) > 1
ORDER BY 
GREATEST(
	COUNT(DISTINCT brand), 
	COUNT(DISTINCT name), 
	COUNT(DISTINCT url),  
	COUNT(DISTINCT category), 
	COUNT(DISTINCT collection)
) DESC;

-- 4.4) Check attributes drift between months:  
-- For each SKU across both months, it computes how many distinct values exist for each attribute.
SELECT 
	sku,
	COUNT(DISTINCT brand) AS n_brand,
	COUNT(DISTINCT name) AS n_name,
	COUNT(DISTINCT category) AS n_category,
	COUNT(DISTINCT collection) AS n_collection,
	COUNT(DISTINCT url) AS n_url
FROM raw.sales_wide
WHERE sku IS NOT NULL AND btrim(sku) <> ''
GROUP BY sku  
HAVING 	COUNT(DISTINCT brand) > 1 
		OR COUNT(DISTINCT name) > 1 
		OR COUNT(DISTINCT url) > 1  
		OR COUNT(DISTINCT category) > 1 
		OR COUNT(DISTINCT collection) > 1
ORDER BY sku; 

-- Check how many SKUs have attribute drifts (729) 
-- Check which attributes are driving the drift(mainly name 687 and category)
SELECT 
	COUNT(DISTINCT sku),
	SUM(CASE WHEN n_brand > 1 THEN 1 ELSE 0 END) AS sku_brand_drift,
	SUM(CASE WHEN n_name > 1 THEN 1 ELSE 0 END) AS sku_name_drift,
	SUM(CASE WHEN n_category > 1 THEN 1 ELSE 0 END) AS sku_category_drift,
	SUM(CASE WHEN n_collection > 1 THEN 1 ELSE 0 END) AS sku_collection_drift,
	SUM(CASE WHEN n_url > 1 THEN 1 ELSE 0 END) AS sku_url_drift
FROM (
	SELECT 
		sku,
		COUNT(DISTINCT brand) AS n_brand,
		COUNT(DISTINCT name) AS n_name,
		COUNT(DISTINCT category) AS n_category,
		COUNT(DISTINCT collection) AS n_collection,
		COUNT(DISTINCT url) AS n_url
	FROM raw.sales_wide
	WHERE sku IS NOT NULL AND btrim(sku) <> ''
	GROUP BY sku  
	HAVING 	
		COUNT(DISTINCT brand) > 1 
		OR COUNT(DISTINCT name) > 1 
		OR COUNT(DISTINCT url) > 1  
		OR COUNT(DISTINCT category) > 1 
		OR COUNT(DISTINCT collection) > 1
	ORDER BY sku
) temp;

-- Drill down query
SELECT
    month_label,
    brand,
    name,
    category,
    collection,
    url
FROM raw.sales_wide
WHERE sku = '06262-PG'
ORDER BY month_order;

-- 5) Build raw.sales_wide_norm table by spliting multi-SKU rows
-- Equivalent to pandas split-and-explode method
DROP TABLE IF EXISTS raw.sales_wide_norm;

CREATE TABLE raw.sales_wide_norm AS 
SELECT 
	s.month_order, 
	s.month_label, 
	s.brand,
	s.name,
	s.category,
	TRIM(sku_split) AS sku, 
	s.url,
	s.collection,

    s.switzerland,
    s.france,
    s.usa,
    s.china,
    s."Hong Kong",
    s.japan,
    s.singapore,
    s.uae,
    s."United Kingdom",
    s."South Korea"
FROM raw.sales_wide s
CROSS JOIN LATERAL 
	unnest(string_to_array(s.sku, ';')) AS sku_split;

-- Verify 
SELECT COUNT(*) FROM raw.sales_wide;
SELECT COUNT(*) FROM raw.sales_wide_norm;

SELECT COUNT(*) FROM raw.sales_wide_norm
WHERE sku LIKE '%;%';

SELECT *
FROM raw.sales_wide_norm
WHERE sku IN ('B4239152', 'B4239150', 'B4211152', 'B4211150');

-- 6) build dimensions by applying "latest-non-null" logic for each attribute
CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.dim_product;

CREATE TABLE analytics.dim_product AS 
SELECT 
sku, 
COALESCE(
	MAX(CASE WHEN month_order = 1 THEN brand END),
	MAX(CASE WHEN month_order = 0 THEN brand END)
) AS brand,
COALESCE(
	MAX(CASE WHEN month_order = 1 THEN name END),
	MAX(CASE WHEN month_order = 0 THEN name END)
) AS name,
COALESCE(
	MAX(CASE WHEN month_order = 1 THEN category END),
	MAX(CASE WHEN month_order = 0 THEN category END)
) AS category,
COALESCE(
	MAX(CASE WHEN month_order = 1 THEN collection END),
	MAX(CASE WHEN month_order = 0 THEN collection END)
) AS collection,
COALESCE(
	MAX(CASE WHEN month_order = 1 AND url IS NOT NULL THEN url END),
	MAX(CASE WHEN month_order = 0 THEN url END)
) AS url
FROM raw.sales_wide_norm
WHERE sku IS NOT NULL AND btrim(sku) <> '' -- where sku is not null and not blank
GROUP BY sku;

-- 5) build facts
DROP TABLE IF EXISTS analytics.fact_sales;

CREATE TABLE analytics.fact_sales AS 
SELECT 
	sku, 
	month_label AS month,
	v.country,
	v.sales_amount 
FROM raw.sales_wide_norm s
CROSS JOIN LATERAL (
	VALUES 
		('Switzerland', s.switzerland),
		('France', s.france),
		('USA', s.usa),
		('China', s.china),
		('Hong Kong', s."Hong Kong"),
		('Japan', s.japan),
		('Singapore', s.singapore),
		('UAE', s.uae),
		('United Kingdom', s."United Kingdom"),
		('South Korea', s."South Korea")
) AS v(country, sales_amount)
WHERE sku IS NOT NULL AND btrim(sku) <> '';

SELECT COUNT(*) FROM analytics.fact_sales;

-- Verify granularity: (sku, month, country) -> one sales_amount 
SELECT 
	sku, month, country, COUNT(*)
FROM analytics.fact_sales
GROUP BY sku, month, country
HAVING COUNT(*) > 1;

-- Verify row counts: Expected long_rows = wide_rows * 10
SELECT 
(SELECT COUNT(*) FROM raw.sales_wide_norm) AS wide_rows,
(SELECT COUNT(*) FROM analytics.fact_sales) AS long_rows;

-- Value-preservation check: totals before vs after unpivot
SELECT 
	(SELECT 
		COALESCE(SUM(switzerland),0) + 
		COALESCE(SUM(france),0) + 
		COALESCE(SUM(usa),0) +
		COALESCE(SUM(china),0) +
		COALESCE(SUM("Hong Kong"),0) +
		COALESCE(SUM(japan),0) +
		COALESCE(SUM(singapore),0) +
		COALESCE(SUM(uae),0) +
		COALESCE(SUM("United Kingdom"),0) +
		COALESCE(SUM("South Korea"),0)
	FROM raw.sales_wide_norm) AS total_sales_wide,
	(SELECT COALESCE(SUM(sales_amount),0) FROM analytics.fact_sales) AS total_sales_long;

-- 6) Build dim_country and dim_time tables 
DROP TABLE IF EXISTS analytics.dim_country;

CREATE TABLE analytics.dim_country AS 
SELECT DISTINCT country
FROM analytics.fact_sales; 

DROP TABLE IF EXISTS analytics.dim_time;

CREATE TABLE analytics.dim_time AS 
SELECT DISTINCT month
FROM analytics.fact_sales; 

