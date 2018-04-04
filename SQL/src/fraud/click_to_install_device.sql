  /* This is a query to get install timestamp and click timestamp for each advertising_id
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@PLATFORM => platform of your app
*/
SELECT e.app_id, e.app_name, e.platform, e.network_name, e.campaign_name, e.acquired_at, ae.clicked_at, e.advertising_id, e.developer_device_id, MAX(e.country) AS country, MAX(e.site_id) AS site_id
FROM (
  SELECT
    e.app_id
    , a.name AS app_name
    , a.platform
    , an.name AS network_name
    , c.name as campaign_name
    , advertising_id
    , developer_device_id
    , source_uuid
    , country
    , site_id
    , min(acquired_at) as acquired_at
  FROM events e
  LEFT JOIN campaigns c
  ON e.source_campaign_id = c.id
  LEFT JOIN ad_networks an
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE e.event = 'open' AND acquired_at >= '@START_DATE' and acquired_at < '@END_DATE'
  AND e.bundle_id = '@BUNDLEID' AND e.platform = '@PLATFORM'
  GROUP BY 1,2,3,4,5,6,7,8,9,10
) AS e
LEFT JOIN (
  SELECT e.app_id, uuid, max(created_at) as clicked_at
  FROM ad_engagements e
  LEFT JOIN campaigns c
  ON e.campaign_id = c.id
  WHERE dateadd('day',7,created_at) >= '@START_DATE'
  AND bundle_id = '@BUNDLEID' AND platform = '@PLATFORM'
  GROUP BY 1,2
) AS ae
ON e.source_uuid = ae.uuid AND e.app_id = ae.app_id
GROUP BY 1,2,3,4,5,6,7,8,9
ORDER BY 1,2,3,4,5,6,7