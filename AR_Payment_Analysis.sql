CREATE DATABASE ar_payment_analysis;
USE ar_payment_analysis;

-- 1. Overall payment-performance KPIs

SELECT
    COUNT(*) AS total_invoices,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    SUM(
        CASE
            WHEN payment_status = 'On Time' THEN 1
            ELSE 0
        END
    ) AS on_time_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,

    ROUND(
        AVG(
            CASE
                WHEN days_late > 0 THEN days_late
            END
        ),
        2
    ) AS avg_delay_days_for_late_invoices

FROM ar_transactions_clean;
-- 2. Payment performance by dispute status
SELECT
    disputed,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,
    ROUND(AVG(days_late), 2) AS avg_days_late

FROM ar_transactions_clean
GROUP BY disputed
ORDER BY late_payment_rate_pct DESC;

-- 3. Payment performance by billing method
SELECT
    paperless_bill,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN disputed = 'Yes' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS dispute_rate_pct

FROM ar_transactions_clean
GROUP BY paperless_bill
ORDER BY late_payment_rate_pct DESC;
-- 4. Payment performance by country code
SELECT
    country_code,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,
    ROUND(AVG(days_late), 2) AS avg_days_late

FROM ar_transactions_clean
GROUP BY country_code
ORDER BY late_payment_rate_pct DESC;
-- 5. Customers with the highest late-payment risk
SELECT
    customer_id,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,
ROUND(AVG(days_late), 2) AS avg_days_late,
    ROUND(MAX(days_late), 0) AS maximum_days_late
FROM ar_transactions_clean
GROUP BY customer_id
HAVING COUNT(*) >= 10
ORDER BY late_payment_rate_pct DESC, total_invoice_amount DESC
LIMIT 10;

SET SQL_SAFE_UPDATES = 0;
UPDATE ar_transactions_clean
SET payment_delay_band =
    CASE
        WHEN days_late = 0 THEN 'On Time'
        WHEN days_late <= 7 THEN '1-7 Days Late'
        WHEN days_late <= 14 THEN '8-14 Days Late'
        WHEN days_late <= 30 THEN '15-30 Days Late'
        ELSE 'Over 30 Days Late'
    END;

SET SQL_SAFE_UPDATES = 1;
-- 6. Invoice distribution by payment-delay band
SELECT
    payment_delay_band,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM ar_transactions_clean),
        2
    ) AS percentage_of_invoices,

    ROUND(
        100.0 * SUM(invoice_amount) /
        (SELECT SUM(invoice_amount) FROM ar_transactions_clean),
        2
    ) AS percentage_of_invoice_value,

    ROUND(AVG(invoice_amount), 2) AS average_invoice_amount

FROM ar_transactions_clean
GROUP BY payment_delay_band
ORDER BY MIN(days_late);

-- 7. Monthly invoice and payment-performance trend
SELECT
    invoice_month,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle

FROM ar_transactions_clean
GROUP BY invoice_month
ORDER BY invoice_month;

-- 8. Payment performance by invoice-value quartile
WITH invoice_value_groups AS (
    SELECT
        invoice_amount,
        payment_status,
        days_to_settle,
        days_late,
        NTILE(4) OVER (ORDER BY invoice_amount) AS value_quartile
    FROM ar_transactions_clean
)

SELECT
    CONCAT('Q', value_quartile) AS invoice_value_quartile,
    COUNT(*) AS total_invoices,
    ROUND(MIN(invoice_amount), 2) AS minimum_invoice_amount,
    ROUND(MAX(invoice_amount), 2) AS maximum_invoice_amount,
    ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

    ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,
    ROUND(AVG(days_late), 2) AS avg_days_late

FROM invoice_value_groups
GROUP BY value_quartile
ORDER BY value_quartile;

-- 9. Billing method and dispute-status interaction
SELECT
    paperless_bill,
    disputed,
    COUNT(*) AS total_invoices,

    SUM(
        CASE
            WHEN payment_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_invoices,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_payment_rate_pct,

ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,
    ROUND(AVG(days_late), 2) AS avg_days_late
FROM ar_transactions_clean
GROUP BY paperless_bill, disputed
ORDER BY disputed DESC, late_payment_rate_pct DESC;


-- 10. Customer risk summary view
CREATE OR REPLACE VIEW vw_customer_risk_summary AS
SELECT
    customer_id,
    total_invoices,
    total_invoice_amount,
    late_invoices,
    late_payment_rate_pct,
    disputed_invoices,
    dispute_rate_pct,
    avg_days_to_settle,
    avg_days_late,

    CASE
        WHEN late_payment_rate_pct >= 60 THEN 'High Risk'
        WHEN late_payment_rate_pct >= 30 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS customer_risk_level

FROM (
    SELECT
        customer_id,
        COUNT(*) AS total_invoices,
        ROUND(SUM(invoice_amount), 2) AS total_invoice_amount,

        SUM(
            CASE
                WHEN payment_status = 'Late' THEN 1
                ELSE 0
            END
        ) AS late_invoices,

        ROUND(
            100.0 * SUM(
                CASE
                    WHEN payment_status = 'Late' THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS late_payment_rate_pct,

        SUM(
            CASE
                WHEN disputed = 'Yes' THEN 1
                ELSE 0
            END
        ) AS disputed_invoices,

        ROUND(
            100.0 * SUM(
                CASE
                    WHEN disputed = 'Yes' THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS dispute_rate_pct,

        ROUND(AVG(days_to_settle), 2) AS avg_days_to_settle,
        ROUND(AVG(days_late), 2) AS avg_days_late

    FROM ar_transactions_clean
    GROUP BY customer_id
) AS customer_summary;
SELECT *
FROM vw_customer_risk_summary
ORDER BY late_payment_rate_pct DESC
LIMIT 10;