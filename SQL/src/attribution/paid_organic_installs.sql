/*
Paid vs organic installs.

Ref: https://help.tenjin.io/t/paid-install-vs-organic-install-analysis/162/17
*/

  SELECT
    e.platform
    , e.country
    , an.name
    , CASE WHEN an.name = 'Organic' then c.name else 'Paid' END as install_type
    , e.acquired_at
    , COUNT(DISTINCT e.advertising_id) AS installs
  FROM (
    SELECT
      app_id
      , platform
      , country
      , acquired_at :: DATE AS acquired_at
      , source_campaign_id
      , advertising_id
    FROM events
    WHERE
      event_type = 'event'
      AND event = 'open'
      AND datediff('sec', acquired_at, created_at) < 86400
      AND acquired_at >= dateadd('day',-30,current_date) -- can replace by a fixed date in the format 'YYYY-MM-DD'
      AND bundle_id = '@BUNDLE_ID' --replace @BUNDLE_ID
      AND country = 'US' -- can replace country
   ) e
  LEFT OUTER JOIN campaigns c
  ON e.source_campaign_id = c.id
  LEFT OUTER JOIN ad_networks an
  ON c.ad_network_id = an.id
  
  GROUP BY
    1,
    2,
    3,
    4,
    5
