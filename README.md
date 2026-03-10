# Luxury Retail Sales Analytics Pipeline

## Project Overview

This project analyzes luxury retail sales across 10 countries at the SKU level.  
The objective is to evaluate product performance, identify key brand and collection drivers, and detect anomalies between two reporting periods (Month **M** and **M-1**).

The project also includes a structured **data quality audit**, identifying several inconsistencies in the raw dataset and documenting the corrective logic applied during modeling.

The analytical workflow consists of:

- Data auditing and normalization in `1.modeling.sql`
- Dimensional modeling using a **star schema** in `1.modeling.sql`
- Analytical SQL queries to evaluate performance and detect anomalies in `2.analysis.sql`
- Visualization through an interactive **Power BI dashboard**

---

## Dataset

The dataset contains retail sales data for a luxury brand portfolio across **10 countries**.

Key characteristics:

- ~9,000 SKU–country observations
- Two reporting periods: **Month M** and **Month M-1**
- Product hierarchy: Category -> Brand -> Collection -> SKU

Each record contains product attributes and sales performance metrics for a given SKU in a given country.

---

## Data Modeling

To support analysis, the dataset was transformed into a **dimensional model (star schema)** implemented in PostgreSQL.

### Fact table

`fact_sales`

Measures:

- Sales value

Dimensions:

- Product
- Country
- Reporting period

### Dimension tables

`dim_product`

Attributes:

- SKU
- Product name
- Category
- Brand
- Collection
- Product URL

`dim_country`

Attributes:

- Country

This structure enables efficient analytical queries and supports downstream BI tools.

---

## Data Quality Audit

During the data preparation phase, several data quality issues were identified.

### Currency inconsistency

Sales values appear to be reported in **local currencies without conversion**.

As a result, aggregating sales across countries produces unrealistic results.  
For example, South Korea accounts for **over 90% of total sales** when values are summed directly.

Therefore, **cross-country comparisons should be interpreted cautiously** unless currency normalization is applied.

---

### Schema inconsistency

Product records in month **M** lack the **URL attribute** that is present in **M-1**.

To address this issue, a **latest non-null propagation rule** was implemented:

If a product URL is missing in month M, the most recent non-null value from month M-1 is used.

---

### Atomicity violation

Two records contain **multiple SKUs in a single field**, violating **First Normal Form (1NF)**.

This issue likely originates from:

- bundled products
- or data entry inconsistencies

These records were flagged during auditing and should ideally be corrected upstream.

---

### Missing hierarchical attributes

Some records contain **missing values in the collection attribute**.

Because collection membership tends to remain stable over time, missing values were imputed using the **latest non-null value from the previous period (M-1)**.

---

### Assortment churn

A significant change in product assortment is observed between the two months:

- **156 SKU changes**
- **115 SKUs disappeared**
- **41 new SKUs appeared**

This may reflect:

- seasonal assortment rotation
- or incomplete historical coverage.

---

## Analysis

Analytical SQL queries were developed to:

- identify **top-performing products**
- evaluate **brand and collection performance**
- detect **sales anomalies between M and M-1**
- highlight data quality issues affecting aggregated results

The analysis results are visualized in a **Power BI dashboard**.

---

## Repository Structure
Sales_Analytics_Pipeline/
- `1.modeling.sql` # dimensional modeling and star schema creation
- `2.analysis.sql` # analytical queries and anomaly detection
- `.gitignore`

---

## Tech Stack

- PostgreSQL
- SQL
- Power BI
- Git / GitHub

---

## Key Skills Demonstrated

- Data auditing and data quality assessment
- Dimensional modeling (star schema)
- Advanced SQL analytics
- Data pipeline structuring
- BI dashboard integration


