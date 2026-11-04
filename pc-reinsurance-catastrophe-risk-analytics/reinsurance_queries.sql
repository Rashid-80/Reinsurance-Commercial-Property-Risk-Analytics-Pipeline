CREATE DATABASE IF NOT EXISTS reinsurance_db;
USE reinsurance_db;


SELECT 
    risk_zone_tier,
    elevationCertificateIndicator AS certificate_status,
    COUNT(id) AS total_claims,
    ROUND(AVG(building_deductible_usd), 0) AS avg_deductible_usd,
    ROUND(AVG(total_claim_paid_usd), 2) AS avg_claim_payout_usd,
    ROUND(SUM(total_claim_paid_usd), 2) AS total_payout_usd
FROM fact_claims
GROUP BY risk_zone_tier, elevationCertificateIndicator
ORDER BY total_payout_usd DESC;

SELECT *
FROM fact_claims;


SELECT 
    eventDesignationNumber AS catastrophe_event,
    yearOfLoss AS loss_year,
    CASE 
        WHEN eventDesignationNumber = 'ATTRITIONAL' THEN 'Normal Weather (Attritional)'
        ELSE 'Named Catastrophe Event'
    END AS event_type,
    COUNT(id) AS claim_count,
    ROUND(SUM(total_claim_paid_usd), 2) AS event_total_loss_usd,
    -- Window Function: Event Loss divided by Grand Total Portfolio Loss
    ROUND(
        SUM(total_claim_paid_usd) * 100.0 / SUM(SUM(total_claim_paid_usd)) OVER (), 
        2
    ) AS pct_of_portfolio_loss
FROM fact_claims
GROUP BY eventDesignationNumber, yearOfLoss
ORDER BY event_total_loss_usd DESC
LIMIT 15;


CREATE OR REPLACE VIEW vw_zipcode_loss_ratio AS
WITH zip_policies AS (
    -- Temporary Table 1: Summarize Premiums & Exposure per ZIP Code
    SELECT 
        zip_code,
        risk_zone_tier,
        SUM(policy_count) AS total_policies,
        ROUND(SUM(written_premium_usd), 2) AS total_premium_usd,
        ROUND(SUM(building_coverage_usd), 2) AS total_insured_value_usd
    FROM fact_policies
    WHERE zip_code != '00000'
    GROUP BY zip_code, risk_zone_tier
),
zip_claims AS (
    -- Temporary Table 2: Summarize Claims Paid per ZIP Code
    SELECT 
        zip_code,
        risk_zone_tier,
        COUNT(id) AS total_claims,
        ROUND(SUM(total_claim_paid_usd), 2) AS total_claims_paid_usd
    FROM fact_claims
    WHERE zip_code != '00000'
    GROUP BY zip_code, risk_zone_tier
)
-- Join the two pre-aggregated tables safely!
SELECT 
    p.zip_code,
    p.risk_zone_tier,
    p.total_policies,
    p.total_premium_usd,
    p.total_insured_value_usd,
    COALESCE(c.total_claims, 0) AS total_claims,
    COALESCE(c.total_claims_paid_usd, 0) AS total_claims_paid_usd,
    -- Calculate Loss Ratio % (Claims Paid / Premiums Collected * 100)
    ROUND(
        COALESCE(c.total_claims_paid_usd, 0) * 100.0 / NULLIF(p.total_premium_usd, 0), 
        2
    ) AS loss_ratio_pct
FROM zip_policies p
LEFT JOIN zip_claims c 
    ON p.zip_code = c.zip_code 
    AND p.risk_zone_tier = c.risk_zone_tier;
    
    

-- Preview the top 10 worst money-losing ZIP codes (with at least 10 policies)
SELECT * 
FROM vw_zipcode_loss_ratio
WHERE total_policies >= 10
ORDER BY loss_ratio_pct DESC
LIMIT 10;


CREATE OR REPLACE VIEW vw_xol_event_simulation AS
WITH event_losses AS (
    SELECT 
        eventDesignationNumber AS catastrophe_event,
        yearOfLoss AS loss_year,
        COUNT(id) AS total_claims,
        ROUND(SUM(total_claim_paid_usd), 2) AS gross_event_loss_usd
    FROM fact_claims
    GROUP BY eventDesignationNumber, yearOfLoss
)
SELECT 
    catastrophe_event,
    loss_year,
    total_claims,
    gross_event_loss_usd,
    -- 1. Insurer pays the first $5M (Attachment Point)
    LEAST(gross_event_loss_usd, 5000000) AS retained_below_attachment_usd,
    -- 2. Reinsurer pays losses above $5M, up to a $25M Limit
    LEAST(25000000, GREATEST(0, gross_event_loss_usd - 5000000)) AS ceded_reinsurer_recovery_usd,
    -- 3. Net Loss kept by the Primary Insurer after Reinsurance Payout
    ROUND(
        gross_event_loss_usd - LEAST(25000000, GREATEST(0, gross_event_loss_usd - 5000000)), 
        2
    ) AS net_retained_loss_usd
FROM event_losses
ORDER BY gross_event_loss_usd DESC;

-- Preview the XoL Reinsurance Simulation results
SELECT * FROM vw_xol_event_simulation LIMIT 10;





SELECT * FROM vw_zipcode_loss_ratio LIMIT 50000;

SELECT * FROM vw_xol_event_simulation LIMIT 50000;

SELECT * FROM fact_claims LIMIT 50000;

SELECT * FROM fact_policies LIMIT 50000;