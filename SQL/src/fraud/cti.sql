/* Compare CTI (clicks divided by installs) per network, per publisher.
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT e.app_name, e.platform, e.network_name, substring(coalesce(e.site_id, ae.site_id),1,10) AS site_id
, SUM(tracked_installs) AS tracked_installs
, SUM(ae.click) AS tracked_clicks
, CASE WHEN SUM(ae.click) = 0 THEN 0 ELSE SUM(tracked_installs)/SUM(ae.click) END :: DOUBLE PRECISION AS cti
FROM (
  SELECT
    e.app_id
    , a.name AS app_name
    , a.platform
    , an.name AS network_name
    , site_id
    , COUNT(distinct coalesce(e.advertising_id, e.developer_device_id)) as tracked_installs
  FROM events e
  LEFT JOIN campaigns c
  ON e.source_campaign_id = c.id
  LEFT JOIN ad_networks an
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE e.event = 'open' AND c.ad_network_id IN (102,42) AND acquired_at >= '@START_DATE' and acquired_at < '@END_DATE'
  AND a.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3,4,5
) AS e
FULL JOIN (
  SELECT ae.app_id, a.name AS app_name, a.platform, an.name AS network_name, site_id, COUNT(*) AS click
  FROM ad_engagements ae
  LEFT OUTER JOIN campaigns c 
  ON ae.campaign_id = c.id
  LEFT OUTER JOIN ad_networks an 
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE event_type = 'click' AND created_at >= '@START_DATE' AND c.ad_network_id = '@AD_NETWORK_ID' AND created_at < '@END_DATE' AND a.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3,4,5
) AS ae
ON e.app_id = ae.app_id AND e.network_name = ae.network_name AND e.site_id = ae.site_id
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4