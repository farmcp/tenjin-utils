/* Click to install time per site_ids. Splitting into 3 buckets. (0m-3m, 3m-1d, 1d+)
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT e.app_name, e.platform, e.network_name, e.site_id,
CASE 
  WHEN datediff(sec, clicked_at, acquired_at) <= 180 THEN '< 3mins'
  WHEN datediff(sec, clicked_at, acquired_at) <= 86400 THEN '< 1day'
  ELSE '> 1day'
  END AS ctit, COUNT(*) AS count 
FROM (
  SELECT
    e.app_id
    , a.name AS app_name
    , a.platform
    , an.name AS network_name
    , c.name as campaign_name
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
  WHERE e.event = 'open' AND c.ad_network_id = '@AD_NETWORK_ID' AND acquired_at >= '@START_DATE' and acquired_at < '@END_DATE'
  AND e.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3,4,5,6,7,8
) AS e
JOIN (
  SELECT ae.app_id, uuid, max(created_at) as clicked_at
  FROM ad_engagements ae
  LEFT OUTER JOIN campaigns c 
  ON ae.campaign_id = c.id
  LEFT OUTER JOIN ad_networks an 
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE event_type = 'click' AND dateadd('day',7,created_at) >= '@START_DATE'
  AND a.bundle_id = '@BUNDLEID' AND c.ad_network_id = '@AD_NETWORK_ID' 
  GROUP BY 1,2
) AS ae
ON e.source_uuid = ae.uuid AND e.app_id = ae.app_id
WHERE datediff(sec, clicked_at, acquired_at) >= 0
GROUP BY 1,2,3,4,5
ORDER BY 1,2,3,4,5