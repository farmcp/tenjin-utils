/* looking at day 3 LTV risk across platform, app, network, country */

SELECT
install_date, app, platform, network, country, d3_rev, tracked_installs,
CASE WHEN tracked_installs = 0 THEN 0 ELSE d3_rev END AS d3_ltv
FROM (
    SELECT
    install_date
    , a.name AS app
    , a.platform
    , an.name AS network
    , country
    , sum(case when days_since_install <= 3 THEN iap_revenue + publisher_ad_revenue ELSE 0 END)/100.0 AS d3_rev
    , sum(case when days_since_install = 0 THEN daily_active_users ELSE 0 END) AS tracked_installs
    FROM reporting_cohort_metrics rm
    LEFT OUTER JOIN campaigns c
    ON rm.campaign_id = c.id
    LEFT OUTER JOIN ad_networks an
    ON c.ad_network_id = an.id
    LEFT OUTER JOIN apps a
    ON c.app_id = a.id
    WHERE install_date >= '2019-02-01' AND a.id in ('f2ca29c6-73a6-4d85-ac64-4a44148155ae','126ffec8-e37d-4b01-ab12-34f3e7f32457')
    GROUP BY 1,2,3,4,5
) a
ORDER BY 1,2,3,4,5;
