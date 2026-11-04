# P&C Reinsurance & Commercial Property Risk Analytics Pipeline
**Tech Stack:** Python (Pandas, Requests, SQLAlchemy) | MySQL (CTEs, Window Functions, Views) | Microsoft Power BI (DAX, Data Modeling)

## 1. Executive Summary & Business Problem
Property & Casualty (P&C) insurers operating in catastrophe-prone coastal states face severe margin erosion from hurricane clustering and unverified property underwriting. 

This end-to-end analytics project ingests **20,000+ real Florida policy and claim records (2020–2026)** from the **OpenFEMA v3 API** to answer two executive questions:
1. **Underwriting Leakage:** Do properties insured without a verified Elevation Certificate generate higher average claim severity, and which ZIP codes exceed a 100% Loss Ratio?
2. **Excess-of-Loss (XoL) Reinsurance Optimization:** How effectively does a **$25M excess of $5M ($25M xs $5M)** per-occurrence catastrophe treaty protect the insurer's balance sheet during peak hurricane seasons?

---

## 2. End-to-End Architecture
1. **Python (API Ingestion & Data Engineering):**
   - Extracted paginated JSON payloads from OpenFEMA v3 endpoints (`NfipClaims` and `NfipPolicies`).
   - Decoded alphanumeric FEMA deductible codes into USD amounts, standardized Special Flood Hazard Area (SFHA) risk tiers (`High Risk A/V Zone` vs. `Moderate/Low Risk X Zone`), and classified missing elevation records into actionable audit tiers.
   - Automated database loading into MySQL via `SQLAlchemy` and `PyMySQL`.
2. **MySQL (Relational Modeling & Actuarial Views):**
   - Resolved multi-grain **fan-out/chasm traps** between policy exposure and claim payouts by pre-aggregating cohorts inside Common Table Expressions (`WITH` CTEs) before joining on ZIP code and risk zone.
   - Engineered SQL views (`vw_zipcode_loss_ratio` and `vw_xol_event_simulation`) utilizing Window Functions (`SUM() OVER()`) and boundary logic (`LEAST`, `GREATEST`) to model treaty attachment points and exhaustion limits.
3. **Microsoft Power BI (Executive Reporting):**
   - Built a 2-page interactive risk monitor tracking Written Premium, Claims Paid, Loss Ratio %, Underwriting Certificate Leakage, and Event-Level XoL Reinsurance Recoveries.

---

## 3. Key Quantified Insights
* **$131.76M Reinsurance Balance-Sheet Protection:** Across **$906.52M** in gross catastrophe and attritional claims (10,000 analyzed Florida claims), applying a **$25M xs $5M XoL treaty** ceded **$131.76M (14.5%)** of tail losses to reinsurers, reducing net retained loss to **$774.76M**.
* **Peak Hurricane Capping:** During major catastrophe events (`FL0124` at **$413.97M** gross loss and `FL0222` at **$318.29M** gross loss), the treaty absorbed the full **$25M** layer limit once primary retention hit the **$5M** attachment point.
* **29% Underwriting Severity Gap:** Claims on properties lacking a verified Elevation Certificate (`No Certificate / Unverified`) averaged **~$93K** per payout compared to **~$72K** for verified properties, exposing significant pricing leakage.
* **ZIP-Level Loss Ratio Hotspots:** Isolated specific high-risk coastal ZIP codes (such as `32011` and `32080`) operating at Loss Ratios above **1,000%**, providing a targeted list for deductible repricing and mandatory elevation audits.

---

## 4. Dashboard Preview
* **Page 1 — Underwriting & Loss Ratio Overview:** Tracks portfolio KPIs, Elevation Certificate severity comparison, and ZIP-level Loss Ratio tables.
* **Page 2 — XoL Reinsurance Treaty Simulator:** Visualizes primary insurer retention ($5M cap) vs. ceded reinsurer recovery ($25M limit) across named catastrophe events.
