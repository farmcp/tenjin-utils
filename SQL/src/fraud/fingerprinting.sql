/* % of installs attributed based on click vs fingerprinting
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT e.app_name, e.platform, e.network_name, e.site_id
, COUNT(distinct coalesce(e.advertising_id, e.developer_device_id)) as tracked_installs
, COUNT(ae.uuid) AS tracked_clicks
, COUNT(distinct ae.advertising_id) AS tracked_clicks_with_advertising_ids
, CASE WHEN COUNT(ae.uuid) = 0 THEN 0 ELSE COUNT(distinct ae.advertising_id)/COUNT(ae.uuid) END :: DOUBLE PRECISION AS percentage_click
, CASE WHEN COUNT(ae.uuid) = 0 THEN 0 ELSE (COUNT(ae.uuid) - COUNT(distinct ae.advertising_id))/COUNT(ae.uuid) END :: DOUBLE PRECISION AS percentage_fingerprinting
FROM (
  SELECT
    e.app_id
    , a.name AS app_name
    , a.platform
    , an.name AS network_name
    , c.name as campaign_name
    , source_uuid
    , advertising_id
    , developer_device_id
    , country
    , site_id
    , MIN(acquired_at) as acquired_at
  FROM events e
  LEFT JOIN campaigns c
  ON e.source_campaign_id = c.id
  LEFT JOIN ad_networks an
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE e.event = 'open' AND c.ad_network_id = '@AD_NETWORK_ID' AND acquired_at >= '@START_DATE' and acquired_at < '@END_DATE'
  AND a.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3,4,5,6,7,8,9,10
) AS e
FULL JOIN (
  SELECT ae.app_id, uuid, advertising_id, max(created_at) as clicked_at
  FROM ad_engagements ae
  LEFT OUTER JOIN campaigns c 
  ON ae.campaign_id = c.id
  LEFT OUTER JOIN ad_networks an 
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE event_type = 'click' AND dateadd('day',7,created_at) >= '@START_DATE' AND c.ad_network_id = '@AD_NETWORK_ID' AND a.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3
) AS ae
ON e.source_uuid = ae.uuid AND e.app_id = ae.app_id
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4