------------------------------------------------------------
------------------   WORLDS LAYOFFS ANALYSIS----------------
------------------------------------------------------------


/* THIS SCRIPT SETS UP THE WORLD'S LAYOFFS DATABASE*/

CREATE DATABASE Worldslayoffs;
GO


USE Worldslayoffs;
GO
/*ENSURES you are working in the correct database context for all subsequent operations.*/



/* This section creates the initial table to hold the raw data from the CSV file.*/


IF OBJECT_ID('dbo.layoffs', 'U') IS NOT NULL
    DROP TABLE dbo.layoffs;
GO

CREATE TABLE dbo.layoffs (
    company                NVARCHAR(MAX),
    location               NVARCHAR(MAX),
    total_laid_off         NVARCHAR(MAX),
    [date]                 NVARCHAR(MAX), 
    percentage_laid_off    NVARCHAR(MAX),
    industry               NVARCHAR(MAX),
    source                 NVARCHAR(MAX),
    stage                  NVARCHAR(MAX),
    funds_raised           NVARCHAR(MAX),
    country                NVARCHAR(MAX),
    date_added             NVARCHAR(MAX)
);
GO

BULK INSERT dbo.layoffs
FROM 'C:\sqldata\layoffs.csv' 
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,           -- Skips the header row
    FIELDTERMINATOR = ',',  
    ROWTERMINATOR = '0x0a', -- Standard for Kaggle/Unix line endings
    TABLOCK
);
GO

-- Add a brand new ID column that automatically numbers itself
ALTER TABLE dbo.layoffs 
ADD row_id INT IDENTITY(1,1) PRIMARY KEY;

-- Look at your data
SELECT TOP 100 * FROM dbo.layoffs;

--lets clean the table with the correct data types
USE [Worldslayoffs];
GO

-- 1. Create the structured table
CREATE TABLE dbo.layoffs_cleaned (
    company               NVARCHAR(255),
    location              NVARCHAR(255),
    total_laid_off        INT,            -- People should be whole numbers
    [date]                DATE,           -- Proper Date format
    percentage_laid_off   FLOAT,          -- Decimals for percentages
    industry              NVARCHAR(255),
    source                NVARCHAR(MAX),  -- Long URLs
    stage                 NVARCHAR(100),
    funds_raised          FLOAT,          -- Millions (with decimals)
    country               NVARCHAR(100),
    date_added            DATE            -- Proper Date format
);
GO

/* This new table, dbo.layoffs_cleaned, is designed to hold the same data as dbo.
layoffs but with proper data types for accurate analysis. */

--------------------------------------------------------------------------
-- Insert data from the raw table into the cleaned table with conversions
--------------------------------------------------------------------------
INSERT INTO dbo.layoffs_cleaned (
    company,
    location,
    total_laid_off,
    [date],
    percentage_laid_off,
    industry,
    source,
    stage,
    funds_raised,
    country,
    date_added

--------------------------------------------------------------------------------

SELECT 
    company,
    location,
    -- Step 1: Handle numbers. Since the CSV has decimals like '400.0', 
    -- we cast to FLOAT first, then to INT.
    TRY_CAST(TRY_CAST(total_laid_off AS FLOAT) AS INT),
    
    -- Step 2: Handle Dates. Format 101 corresponds to mm/dd/yyyy
    TRY_CONVERT(DATE, [date], 101),
    
    -- Step 3: Handle Floats
    TRY_CAST(percentage_laid_off AS FLOAT),
    
    industry,
    source,
    stage,
    TRY_CAST(funds_raised AS FLOAT),
    country,
    
    -- Step 4: Handle the second date column
    TRY_CONVERT(DATE, date_added, 101)
FROM dbo.layoffs;
GO

/* This process converts the raw string data into structured formats, allowing for accurate analysis and querying.*/ 

----------------------------------------
--1. Remove duplicate rows
-----------------------------------------

WITH Duplicate_CTE AS (
    SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, [date], stage, country, funds_raised
        ORDER BY (SELECT NULL)
    ) AS row_num
    FROM dbo.layoffs_cleaned
)
DELETE FROM Duplicate_CTE
WHERE row_num > 1;
GO

/* This step ensures that any duplicate entries in the dataset are removed*/

----------------------------------
--2.standardize and fix nulls
-----------------------------------

UPDATE dbo.layoffs_cleaned
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Standardize 'Travel' and 'Transportation' (sometimes they overlap)
UPDATE dbo.layoffs_cleaned
SET industry = 'Transportation'
WHERE industry LIKE 'Transport%';

------------------------------------------------------------------------
-- 3. Fix any row that accidentally has a number or percentage in it
-- If it's a number, it's likely misaligned data, so we set it to 'Other'
---------------------------------------------------------------------------

UPDATE dbo.layoffs_cleaned
SET industry = 'Other'
WHERE industry LIKE '%[0-9]%' 
   OR industry LIKE '%\%%' ESCAPE '\';

   /* This step ensures that any industry entries that contain numbers
   (which are likely errors from misaligned CSV data) or percentage signs (which don't belong in an industry name)
   are standardized to 'Other' for consistency in analysis.*/


--------------------------------------------
-- 4. Clean up leading/trailing white spaces
--------------------------------------------

UPDATE dbo.layoffs_cleaned
SET industry = TRIM(industry);
GO

/* This step ensures that all industry names are consistent and free from any
accidental spaces that could cause issues in grouping or analysis later on.*/

------------------------
--5.Handle nulls or blanks
------------------------- 
UPDATE dbo.layoffs_cleaned
SET industry = 'Other'
WHERE industry IS NULL OR industry = '' OR industry = 'None';
GO

/*This cleaning process ensures that the dataset is consistent and ready for analysis,*/

---------------------------------------------------------------------------
---6.create a view to filter out the empty rows for the mathematical analysis
---------------------------------------------------------------------------

CREATE VIEW dbo.layoffs_final AS
SELECT *
FROM dbo.layoffs_cleaned
WHERE total_laid_off IS NOT NULL
  AND percentage_laid_off IS NOT NULL
  AND [date] IS NOT NULL
  AND funds_raised IS NOT NULL;
  GO

  /* this view, dbo.layoffs_final, serves as a clean and reliable dataset for all subsequent analyses, 
  ensuring that we only work with complete and accurate records of layoffs.*/


  ----------------------------------------------------------
  --7.The "Market Sentiment" Analysis: Year-over-Year Growth
  --Is the layoff crisis accelerating or stabilizing? 
  ----------------------------------------------------------

 WITH Yearly_Total AS (
    SELECT 
        YEAR([date]) AS Year,
        SUM(total_laid_off) AS Total_Laid_Off
    FROM dbo.layoffs_final
    GROUP BY YEAR([date])
    ),
    Yearly_Change AS (
    SELECT 
        Year,
        Total_Laid_Off,
        LAG(Total_Laid_Off) OVER (ORDER BY Year) AS Previous_Year_Total,
        CASE 
            WHEN LAG(Total_Laid_Off) OVER (ORDER BY Year) IS NULL THEN NULL
            ELSE ((Total_Laid_Off - LAG(Total_Laid_Off) OVER (ORDER BY Year)) * 100.0) / LAG(Total_Laid_Off) OVER (ORDER BY Year)
        END AS Percentage_Change
        FROM Yearly_Total
        )
        SELECT
        Year,
        Total_Laid_Off,
        Previous_Year_Total,
        Percentage_Change
        FROM Yearly_Change
        ORDER BY Year;

------------------------------------------------------------
--  8.Which industries are most prone to "Mass Layoffs" 
--(events where > 500 people are let go) vs. "Small Trims"?
-------------------------------------------------------------

SELECT 
    industry,
    SUM(CASE WHEN total_laid_off > 500 THEN 1 ELSE 0 END) AS Mass_Layoffs,
    SUM(CASE WHEN total_laid_off <= 500 THEN 1 ELSE 0 END) AS Small_Trims
    FROM dbo.layoffs_final
    GROUP BY industry
    ORDER BY Mass_Layoffs DESC;

    /*results show that the Technology industry has the highest number of mass layoffs,
    while industries like Retail and Healthcare have more small trims compared to mass layoffs.
    */

-----------------------------------------------------------------------------
--9. Identify the top 3 cities in every country that experienced the most layoffs.
------------------------------------------------------------------------------

wITH City_Layoffs AS (
    SELECT 
        country,
        location,
        SUM(total_laid_off) AS Total_Laid_Off
    FROM dbo.layoffs_final
    GROUP BY country, location
    ),
    Ranked_Cities AS (
    SELECT 
        country,
        location,
        Total_Laid_Off,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY Total_Laid_Off DESC) AS Rank
    FROM City_Layoffs
    )
    SELECT 
        country,
        location,
        Total_Laid_Off
    FROM Ranked_Cities
    WHERE Rank <= 3
    ORDER BY Total_Laid_Off DESC;

 /*results show that the United States has the highest layoffs in cities like San Francisco, 
 New York, and Los Angeles, while other countries have their own hotspots for layoffs.*/



-------------------------------------------------------------------
--10.Are layoffs statistically higher in Q1 (January-March) than in Q4?
-------------------------------------------------------------------

SELECT 
    CASE 
        WHEN MONTH([date]) IN (1, 2, 3) THEN 'Q1'
        WHEN MONTH([date]) IN (10, 11, 12) THEN 'Q4'
        ELSE 'Other'
    END AS Quarter,
    SUM(total_laid_off) AS Total_Laid_Off
    FROM dbo.layoffs_final
    WHERE MONTH([date]) IN (1, 2, 3, 10, 11, 12)
    GROUP BY
    CASE 
        WHEN MONTH([date]) IN (1, 2, 3) THEN 'Q1'
        WHEN MONTH([date]) IN (10, 11, 12) THEN 'Q4'
        ELSE 'Other'
    END

    -- results show that Q1 has significantly higher layoffs than Q4, indicating a potential seasonal trend in layoffs.
    /*Quarter	Total_Laid_Off
    ------------------------------
         Q1	    195764
         Q4	    109411*/

-------------------------------------------------------------
--11.which companies had to close down completely (100% layoffs) 
--------------------------------------------------------------

SELECT
    company,
    industry,
    [date],
    country,
    percentage_laid_off
    FROM dbo.layoffs_final
    WHERE percentage_laid_off = 1
    ORDER BY [date] DESC;

    --results show that several companies across various industries had to close down completely, with a significant number of closures occurring in the Technology and Retail sectors
    -- The most recent closures are from 2025, indicating ongoing challenges in the business landscape.

    ---------------------------------------------------------------------
    --12.At what growth stage (Seed, Post-IPO, etc.) do most layoffs happen?
    ---------------------------------------------------------------------

    SELECT
    stage,
    COUNT(*) AS Layoff_Events
    FROM dbo.layoffs_final
    GROUP BY stage
    ORDER BY Layoff_Events DESC;

    --results show that most layoffs occur in the "Growth" stage, 
    --followed by "Post-IPO" and "Seed" stages, suggesting that companies in their expansion phase are more vulnerable to workforce reductions.

------------------------------------------------------------------------------
--13.How does the amount of funds raised correlate with the likelihood of layoffs?
-------------------------------------------------------------------------------

SELECT 
    stage,
   round(AVG(funds_raised),2) AS Average_Funds_Raised,
    Round(AVG(percentage_laid_off),2) AS Average_Percentage_Laid_Off
    FROM dbo.layoffs_final
    GROUP BY stage
    ORDER BY Average_Funds_Raised DESC;

    /*results show that companies in the "Growth" stage have raised
    the most funds on average but also have a higher average percentage of layoffs,
    indicating that even well-funded companies are not immune to workforce reductions during expansion phases.*/

    --------------------------------------------
    --14.How Many People lost their jobs each year?
    ---------------------------------------------
    SELECT
    YEAR([date]) AS Year,       
    SUM(total_laid_off) AS Total_Laid_Off
    FROM dbo.layoffs_final
    GROUP BY YEAR([date])
    ORDER BY Year;

    /* results
    -------------------------
    Year	Total_Laid_Off
    --------------------------
       2020	      60960
       2021       6490
       2022	      126427
       2023	      158463
       2024	      103488
       2025	      81681
       2026	      15414

       results show that the number of layoffs peaked in 2023, 
       likely due to the economic impacts of the COVID-19 pandemic and subsequent market adjustments, 
       with a significant decline in layoffs in 2024 and 2025 as companies stabilized and adapted to new market conditions. */


     ----------------------------------------------
    --15.Which 10 companies had the biggest layoffs?
   -------------------------------------------------

    select top 10
    company,
    industry,
    [date],
    country,
    total_laid_off
    from dbo.layoffs_final
    order by total_laid_off desc;

    --results show that the companies with the biggest layoffs are primarily in the Technology and Retail industries,
    --with Intel, Amazon, and Tesla leading the list.
    /*
    company 	industry	  date	       country	           total_laid_off
    Intel	  Hardware	 2025-04-23	    United States	       22000
    Intel	  Hardware	 2024-08-01	    United States	        15000
    Amazon	 Retail	     2025-10-27	    United States	        14000
    Tesla	Transportation	2024-04-15  United States	    14000
    Google	Consumer	  2023-01-2	    United States	        12000
    Meta	Consumer	2022-11-09	    United States	        11000
    Microsoft	Other	2023-01-18	    United States	        10000
    Amazon	Retail	    2022-11-16	    United States	        10000
    Microsoft	Other	2025-07-02	    United States	        9000
    Ericsson	Other	2023-02-24	    Sweden	                8500 */
