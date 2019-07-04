/*
monetization metrics eCPM and ARPDAU
eCPM: ad_revenue / impressions * 1000
ARPDAU: iap + ad_revenue / users

apps where users is null do not have our SDK.
change the impressions threshold to only consider apps with enough traffic.

*/
SELECT
      coalesce(r.country, 'un') AS country
    , r.app_name
    , r.platform
    , SUM(users) AS users
    , SUM(iap_revenue)/100.0 AS iap_revenue
    , SUM(ad_revenue)/100.0 AS ad_revenue
    , SUM(impressions) AS ad_impressions
    , SUM(ad_revenue)*10/NULLIF(SUM(impressions),0):: DOUBLE PRECISION AS eCPM
    , SUM(iap_revenue + ad_revenue)/(100.0 * NULLIF(SUM(users),0)) AS ARPDAU
  FROM (
        SELECT DATE,
               pa.app_id,
               a.name AS app_name,
               a.platform,
               country,
               SUM(revenue) AS ad_revenue,
               SUM(impressions) AS impressions
        FROM daily_ad_revenue r
          LEFT OUTER JOIN publisher_apps pa
          ON r.publisher_app_id = pa.id
          LEFT OUTER JOIN apps a
          ON pa.app_id = a.id
        WHERE date >= '2018-04-30' AND date <= '2018-05-07' -- change dates here
        GROUP BY 1,
                 2,
                 3,
                 4,
                 5
  ) r
  LEFT OUTER JOIN (
    SELECT
      created_at :: DATE AS created_at
      , e.app_id
      , a.name AS app_name
      , a.platform
      , country
      , COUNT(distinct(CASE WHEN e.event = 'open' THEN coalesce(advertising_id, developer_device_id) END)) AS users
      , SUM(CASE WHEN event_type = 'purchase' AND purchase_state in (0,3) THEN revenue ELSE 0 END) AS iap_revenue
    FROM events e
    LEFT OUTER JOIN campaigns c
    ON e.source_campaign_id = c.id
    LEFT OUTER JOIN apps a
    ON c.app_id = a.id
    WHERE created_at >= '2018-04-30' AND created_at <= '2018-05-07' -- change dates here
    GROUP BY 1,2,3,4,5
  ) s
  ON r.date = s.created_at AND r.app_id = s.app_id AND r.country = s.country
  GROUP BY 1,2,3
  HAVING SUM(ad_revenue) > 0 AND SUM(impressions) >= 200 -- impression threshold
  ORDER BY 8 DESC
