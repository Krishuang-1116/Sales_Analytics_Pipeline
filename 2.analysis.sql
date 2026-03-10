-- 01 -- analysis.sql
-- 1) Pivot to create table: sku, month, sales_m_1, sales_m, abs_change, pct_change
-- 2) Create anomaly signs
DROP TABLE IF EXISTS analytics.sales_comparison;

CREATE TABLE analytics.sales_comparison AS 
WITH base AS(
	SELECT 
		sku,
		country,
		SUM(CASE WHEN month = 'M-1' THEN sales_amount END) AS sales_m_1, 
		SUM(CASE WHEN month = 'M' THEN sales_amount END) AS sales_m
	FROM analytics.fact_sales
	GROUP BY sku, country
),
intermediary AS (
	SELECT
		sku,
		country,
		sales_m_1,
		sales_m,
		sales_m - sales_m_1 AS abs_change,
		CASE 
			WHEN sales_m_1 IS NULL OR sales_m_1 = 0 THEN NULL
			ELSE ROUND((sales_m / sales_m_1 - 1) * 100 , 2)
		END AS pct_change_pct
	FROM base
)

SELECT 
	sku,
	country,
	sales_m_1,
	sales_m,
	abs_change,
	pct_change_pct,
	CASE  -- existence analysis > numeric analysis
		WHEN sales_m_1 IS NULL AND sales_m IS NOT NULL THEN 'new'
		WHEN sales_m IS NULL AND sales_m_1 IS NOT NULL THEN 'disappeared'
		WHEN pct_change_pct <= -20 THEN 'strong decline' 
		WHEN pct_change_pct >=20 THEN 'strong increase' 
		ELSE 'Stable'
	END AS anomaly_flag
FROM intermediary;

-- Drill down 
	-- # of occurrences
SELECT
(SELECT COUNT(*) FROM analytics.sales_comparison WHERE anomaly_flag = 'strong decline') AS n_declines,
(SELECT COUNT(*) FROM analytics.sales_comparison WHERE anomaly_flag = 'strong increase') AS n_increases,
(SELECT COUNT(*) FROM analytics.sales_comparison WHERE anomaly_flag = 'new') AS n_new,
(SELECT COUNT(*) FROM analytics.sales_comparison WHERE anomaly_flag = 'disappeared') AS n_disappeared;

	-- Verify new and disppeared skus 
SELECT 
	s.sku, 
	s.country,
	s.anomaly_flag,
	p.* 
FROM analytics.sales_comparison s
JOIN analytics.dim_product p ON s.sku = p.sku
WHERE anomaly_flag = 'new' OR anomaly_flag = 'disappeared';
