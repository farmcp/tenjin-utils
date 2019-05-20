/*
Updated on 2018-07-20.
Closest SQL to reproduce a mix between reporting_metrics and reporting_cohort_metrics.
Need to be re-written as we will decommission cohort_behavior
limit to 100 for display
*/
WITH temp_cohort AS (
  -- calculate session by xday, acquired_at, created_at, campaign_id, app_id, country, site
  SELECT
    created_at :: DATE AS created_at
    , datediff('sec', acquired_at, created_at) / 86400 AS xday
    , acquired_at :: DATE AS acquired_at
    , coalesce(c.campaign_bucket_id, c.id) AS campaign_id
    , e.app_id
    , coalesce(country, 'unknown') AS country
    , coalesce(site_id, 'unknown') AS site_id
    , COUNT(distinct(CASE WHEN e.event = 'open' THEN coalesce(advertising_id, developer_device_id) END)) AS users
    , COUNT(CASE WHEN e.event = 'open' THEN 1 END) AS sessions
    , SUM(COUNT(CASE WHEN e.event = 'open' THEN 1 END)) over (partition by created_at::date, e.app_id, coalesce(country, 'unknown')) AS app_country_sessions
    , SUM(CASE WHEN event_type = 'purchase' AND purchase_state in (0,3) THEN revenue ELSE 0 END) AS iap_revenue
  FROM events e
  LEFT OUTER JOIN campaigns c
  ON e.source_campaign_id = c.id
  WHERE created_at >= date_trunc('month',date_add('day', -60, current_date)) -- change date like '2018-06-01' if you want. don't add acquired_at
  GROUP BY 1,2,3,4,5,6,7
),
temp_session as (
   SELECT * FROM (
     -- calculate session by created_at, campaign_id, app_id, country, site
    SELECT
      created_at :: DATE AS created_at
      , coalesce(c.campaign_bucket_id, c.id) AS campaign_id
      , e.app_id
      , coalesce(country, 'unknown') AS country
      , coalesce(site_id, 'unknown') AS site_id
      , COUNT(CASE WHEN e.event = 'open' THEN 1 END) AS sessions
      , COUNT(distinct(CASE WHEN e.event = 'open' THEN coalesce(advertising_id, developer_device_id) END)) AS users
      , SUM(COUNT(CASE WHEN e.event = 'open' THEN 1 END)) over (partition by created_at::date, e.app_id, coalesce(country, 'unknown')) AS app_country_sessions
      , SUM(CASE WHEN event_type = 'purchase' AND purchase_state in (0,3) THEN revenue ELSE 0 END) AS iap_revenue
    FROM events e
    LEFT OUTER JOIN campaigns c
    ON e.source_campaign_id = c.id
    WHERE created_at >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
    GROUP BY 1,2,3,4,5
  ) e1
  WHERE app_country_sessions > 0
)
SELECT
  coalesce(cb.date, pr.created_at, ds.date) AS date
  , a.name AS application
  , a.platform
  , an.name AS ad_network
  , c.name AS campaign_name
  , coalesce(cb.country, pr.country, ds.country) AS country
  , coalesce(cb.site_id, pr.site_id, ds.site_id) AS site_id
  , SUM(pr.iap_revenue) AS iap_revenue
  , SUM(pr.ad_revenue) AS ad_revenue
  , SUM(pr.users) AS dau
  , SUM(cb.tracked_installs) AS tracked_installs
  , SUM(cb.d1_iap_rev) as d1_iap_rev
  , SUM(cb.d3_iap_rev) as d3_iap_rev
  , SUM(cb.d7_iap_rev) as d7_iap_rev
  , SUM(cb.d30_iap_rev) as d30_iap_rev
  , SUM(pr2.d1_ad_rev) as d1_ad_rev
  , SUM(pr2.d3_ad_rev) as d3_ad_rev
  , SUM(pr2.d7_ad_rev) as d7_ad_rev
  , SUM(pr2.d30_ad_rev) as d30_ad_rev
  , SUM(d1_users) AS d1_users
  , SUM(d3_users) AS d3_users
  , SUM(d7_users) AS d7_users
  , SUM(d30_users) AS d30_users
  , SUM(ds.impressions) AS impressions
  , SUM(ds.clicks) AS clicks
  , SUM(ds.installs) AS reported_installs
  , SUM(CASE WHEN ds.spend IS NULL THEN 0 ELSE ds.spend END) AS spend
FROM (
  -- get tracked_installs and xday IAP revenue from cohort_behavior(pre-aggregated table)
  SELECT
    date, app_id, coalesce(c.campaign_bucket_id, c.id) AS campaign_id, country, site_id
    , SUM(CASE WHEN xday = 0 THEN users END) AS tracked_installs
    , SUM(CASE WHEN xday <= 1 THEN revenue ELSE 0 END)/100.0 AS d1_iap_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 3 THEN revenue ELSE 0 END)/100.0 AS d3_iap_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 7 THEN revenue ELSE 0 END)/100.0 AS d7_iap_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 30 THEN revenue ELSE 0 END)/100.0 AS d30_iap_rev -- change xday if you want
    , SUM(CASE WHEN xday = 1 THEN users END) AS d1_users
    , SUM(CASE WHEN xday = 3 THEN users END) AS d3_users
    , SUM(CASE WHEN xday = 7 THEN users END) AS d7_users
    , SUM(CASE WHEN xday = 30 THEN users END) AS d30_users
  FROM cohort_behavior cb
  LEFT OUTER JOIN campaigns c
  ON cb.campaign_id = c.id
  WHERE date >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
  GROUP BY 1,2,3,4,5
) cb
FULL OUTER JOIN (
  -- get daily ad revenue
  SELECT
    s.created_at
    , coalesce(s.campaign_id, 'N/A') AS campaign_id
    , s.app_id
    , s.country
    , s.site_id
    , SUM(revenue * sessions::float / nullif(app_country_sessions, 0))/100.0 AS ad_revenue
    , SUM(impressions * sessions::float / nullif(app_country_sessions, 0)) AS ad_impressions
    , SUM(iap_revenue)/100.0 AS iap_revenue
    , SUM(users) AS users
  FROM (
    SELECT date, app_id, country, SUM(revenue) AS revenue, SUM(impressions) AS impressions
    FROM daily_ad_revenue r
    LEFT OUTER JOIN publisher_apps p
    ON p.id = r.publisher_app_id
    WHERE date >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
    GROUP BY 1,2,3
  ) r
  INNER JOIN temp_session s
  ON r.date = s.created_at AND r.app_id = s.app_id AND r.country = s.country
  GROUP BY 1,2,3,4,5

  -- union all needed for ad revenue from apps that do not have our SDK
  UNION ALL
  SELECT
    r.date AS created_at
    , 'N/A' AS campaign_id
    , r.app_id
    , r.country AS country
    , 'unknown' AS site_id
    , SUM(revenue)/100.0 AS ad_revenue
    , SUM(impressions) AS ad_impressions
    , SUM(iap_revenue)/100.0 AS iap_revenue
    , SUM(users) AS users
  FROM (
    SELECT date, app_id, bundle_id, country, SUM(revenue) AS revenue, SUM(impressions) AS impressions
    FROM daily_ad_revenue r
    LEFT OUTER JOIN publisher_apps p
    ON p.id = r.publisher_app_id
    LEFT OUTER JOIN apps a
    ON p.app_id = a.id
    WHERE date >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
    GROUP BY 1,2,3,4
  ) r
  LEFT OUTER JOIN temp_session s
  ON r.date = s.created_at AND r.app_id = s.app_id AND r.country = s.country
  INNER JOIN (
    SELECT bundle_id
    FROM cohort_behavior cb
    LEFT OUTER JOIN campaigns c
    ON cb.campaign_id = c.id
    LEFT OUTER JOIN apps a
    ON c.app_id = a.id
    WHERE date >= date_trunc('month',date_add('day', -60, current_date))
    GROUP BY 1
  ) cb
  ON r.bundle_id = cb.bundle_id
  WHERE s.created_at IS NULL OR s.app_id IS NULL OR s.country IS NULL
  GROUP BY 1,2,3,4,5
) pr
ON cb.date = pr.created_at AND cb.campaign_id = pr.campaign_id AND cb.app_id = pr.app_id AND cb.country = pr.country AND cb.site_id = pr.site_id
LEFT OUTER JOIN (
  -- get ad revenue LTV
  SELECT
    acquired_at
    , campaign_id
    , app_id
    , country
    , site_id
    , SUM(CASE WHEN xday <= 1 THEN ad_rev ELSE 0 END)/100.0 AS d1_ad_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 3 THEN ad_rev ELSE 0 END)/100.0 AS d3_ad_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 7 THEN ad_rev ELSE 0 END)/100.0 AS d7_ad_rev -- change xday if you want
    , SUM(CASE WHEN xday <= 30 THEN ad_rev ELSE 0 END)/100.0 AS d30_ad_rev -- change xday if you want
  FROM (
    SELECT
      s.acquired_at
      , coalesce(s.campaign_id, 'N/A') AS campaign_id
      , s.app_id
      , s.country
      , s.site_id
      , xday
      , SUM(revenue * sessions::float / nullif(app_country_sessions, 0)) AS ad_rev
    FROM (
      SELECT date, app_id, country, SUM(revenue) AS revenue, SUM(impressions) AS impressions
      FROM daily_ad_revenue r
      LEFT OUTER JOIN publisher_apps p
      ON p.id = r.publisher_app_id
      WHERE date >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
      GROUP BY 1,2,3
    ) r
    INNER JOIN temp_cohort s
    ON r.date = s.created_at AND r.app_id = s.app_id AND r.country = s.country
    WHERE acquired_at >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
    GROUP BY 1,2,3,4,5,6
    having SUM(app_country_sessions) > 0
  ) pr1
  GROUP BY 1,2,3,4,5
) pr2
ON cb.date = pr2.acquired_at AND cb.campaign_id = pr2.campaign_id AND cb.app_id = pr2.app_id AND cb.country = pr2.country AND cb.site_id = pr2.site_id
FULL OUTER JOIN (
  -- get spend and reported_installs
SELECT
    r.date
    , coalesce(r.campaign_id, 'N/A') AS campaign_id
    , s.app_id
    , r.country
    , s.site_id
    , SUM(nvl(spend * users_0d::float / nullif(campaign_country_users_0d, 0),spend))/100.0 AS spend
    , SUM(nvl(impressions * users_0d::float / nullif(campaign_country_users_0d, 0),impressions)) AS impressions
    , SUM(nvl(clicks * users_0d::float / nullif(campaign_country_users_0d, 0),clicks)) AS clicks
    , SUM(nvl(installs * users_0d::float / nullif(campaign_country_users_0d, 0),installs)) AS installs
  FROM (
    SELECT
      date, app_id, coalesce(c.campaign_bucket_id, c.id) AS campaign_id
      , CASE WHEN country = 'UNKNOWN' THEN 'unknown' ELSE country END AS country, SUM(impressions) AS impressions, SUM(clicks) AS clicks, SUM(installs) AS installs, SUM(spend) AS spend
    FROM daily_country_spend dcs
    LEFT OUTER JOIN campaigns c
    ON dcs.campaign_id = c.id
    WHERE date >= date_trunc('month',date_add('day', -60, current_date)) -- change date if you want
    GROUP BY 1,2,3,4
  ) r
  LEFT OUTER JOIN (
    SELECT
      acquired_at AS cohort, app_id, campaign_id, country, site_id
      , SUM(users) AS users_0d
      , SUM(SUM(users)) over (partition by cohort, app_id, campaign_id, country) AS campaign_country_users_0d
    FROM temp_cohort s1
    WHERE s1.xday = 0 AND s1.users > 0
    GROUP BY 1,2,3,4,5
  ) s
  ON r.date = s.cohort AND r.app_id = s.app_id AND r.campaign_id = s.campaign_id AND r.country = s.country
  GROUP BY 1,2,3,4,5

  UNION ALL

  -- union all to catch spend from network that are not in daily_country_spend
  SELECT
    r.date
    , coalesce(r.campaign_id, 'N/A') AS campaign_id
    , r.app_id
    , s.country
    , s.site_id
    , SUM(spend * users_0d::float / nullif(campaign_users_0d, 0))/100.0 AS spend
    , SUM(impressions * users_0d::float / nullif(campaign_users_0d, 0)) AS impressions
    , SUM(clicks * users_0d::float / nullif(campaign_users_0d, 0)) AS clicks
    , SUM(installs * users_0d::float / nullif(campaign_users_0d, 0)) AS installs
  FROM (
    SELECT
      date, app_id, coalesce(c.campaign_bucket_id, c.id) AS campaign_id
      , 'unknown' AS country, SUM(impressions) AS impressions, SUM(clicks) AS clicks, SUM(installs) AS installs, SUM(spend) AS spend
    FROM daily_spend ds
    LEFT OUTER JOIN campaigns c
    ON ds.campaign_id = c.id
    LEFT OUTER JOIN (
      SELECT campaign_id FROM daily_country_spend
      GROUP BY 1
    ) dcs
    ON ds.campaign_id = dcs.campaign_id
    WHERE date >= date_trunc('month',date_add('day', -60, current_date)) AND dcs.campaign_id IS NULL-- change date if you want
    GROUP BY 1,2,3,4
  ) r
  INNER JOIN (
    SELECT
      acquired_at AS cohort, app_id, campaign_id, country, site_id
      , SUM(users) AS users_0d
      , SUM(SUM(users)) over (partition by cohort, app_id, campaign_id) AS campaign_users_0d
    FROM temp_cohort s1
    WHERE s1.xday = 0 AND s1.users > 0
    GROUP BY 1,2,3,4,5
  ) s
  ON r.date = s.cohort AND r.app_id = s.app_id AND r.campaign_id = s.campaign_id
  GROUP BY 1,2,3,4,5
) ds
ON cb.date = ds.date AND cb.campaign_id = ds.campaign_id AND cb.app_id = ds.app_id AND cb.country = ds.country AND cb.site_id = ds.site_id
-- add campaign info
LEFT OUTER JOIN bucket_campaign_info c
ON coalesce(cb.campaign_id, pr.campaign_id, ds.campaign_id) = c.id
-- add ad-network info
LEFT OUTER JOIN ad_networks an
ON c.ad_network_id = an.id
-- add app info
LEFT OUTER JOIN apps a
ON coalesce(c.app_id, pr.app_id) = a.id
GROUP BY 1,2,3,4,5,6,7;
