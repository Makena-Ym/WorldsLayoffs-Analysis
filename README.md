# 📉 Global Layoffs Data Analysis: 2020 - 2026
> **A Comprehensive SQL Data Cleaning & Exploratory Data Analysis Project**

## 📝 Project Overview
In this project, I performed a deep dive into a global dataset of company layoffs. The goal was to take a raw, messy CSV file and transform it into a structured database capable of answering critical business questions.

This analysis tracks the impact of layoffs across different **industries**, **countries**, and **company stages**, providing a clear picture of economic shifts from the start of the pandemic through 2026.

---

## 🛠️ The Data Engineering Workflow

### 1. Data Cleaning & Transformation 🧹
Raw data is rarely ready for analysis. I followed a strict process to ensure data integrity:
* **Staging:** Imported raw data into a temporary table to keep the original source safe.
* **Type Casting:** Converted text-based dates and numbers into `DATE`, `INT`, and `FLOAT` types to allow for mathematical calculations.
* **Standardization:** Fixed inconsistent naming (e.g., merging different variations of 'Crypto' into one standard category).
* **Removing Duplicates:** Used **Common Table Expressions (CTEs)** and `ROW_NUMBER()` to identify and delete identical records.

### 2. Analytical View Creation 👁️
I created a SQL **View** called `v_layoffs_analytics`. This view filters out records that lack numerical data, ensuring that my averages and totals remain accurate without deleting the original records.

---

## 📊 Business Insights & Key Findings

Below are the key questions I answered using SQL:

### 🏢 Industry Impact
* **Question:** Which sectors faced the highest job losses?
* **Insight:** Data reveals that **Finance** and **Retail** were among the hardest-hit industries, followed by significant cuts in the **Consumer** and **Transportation** sectors.

### 🌎 Geographic Trends
* **Question:** Which countries are the most affected?
* **Insight:** The **United States** leads in total layoffs, but significant activity was also observed in tech hubs across **India**, the **Netherlands**, and **Brazil**.

### 📈 Company Growth Stages
* **Question:** Do well-funded "Unicorns" survive better?
* **Insight:** Surprisingly, **Post-IPO** companies account for the largest volume of layoffs, while companies in the **Growth** stage often show higher percentage-based cuts relative to their size.

### 📅 Time-Series Analysis
* **Question:** When did the layoffs peak?
* **Insight:** Layoffs peaked significantly in **2023**, with secondary spikes occurring in early **2024** and **2025** as market conditions adjusted.

---

## 💻 SQL Techniques Showcased
To complete this analysis, I utilized advanced SQL features including:
* **Common Table Expressions (CTEs)** for data deduplication.
* **Window Functions** (`DENSE_RANK`, `SUM OVER`) for running totals and rankings.
* **Aggregate Functions** (`SUM`, `AVG`, `COUNT`) for high-level summaries.
* **Data Casting & Conversion** for schema management.
* **CASE Statements** to categorize companies by layoff size (Massive, Large, Medium, Small).

---

## 📂 Project Structure
* `worldslayoffs.sql`: The full SQL script containing the cleaning process and all analytical queries.
* `layoffs.csv`: The original raw dataset used for the project.
* `README.md`: Project documentation (this file).

---

## 🚀 How to Use
1.  Clone this repository.
2.  Open **SQL Server Management Studio (SSMS)**.
3.  Run the `worldslayoffs.sql` script to create the database and populate the tables.
4.  Explore the queries in the "Business Questions" section of the script to see the results.

---

### 👨‍💻 Author
**Yvonne Makena** *Data Analyst*
