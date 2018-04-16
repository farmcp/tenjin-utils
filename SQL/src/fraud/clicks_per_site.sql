/* % of clicks without advertising_id, per site_id. 
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT
  a.name AS app_name, a.platform, an.name AS network_name, substring(site_id,1,10) as site_id
  , COUNT(distinct uuid) AS clicks
  , COUNT(distinct advertising_id) AS clicks_with_advertising_id
  , CASE WHEN COUNT(distinct uuid) = 0 THEN 0 ELSE (COUNT(distinct uuid) - COUNT(distinct advertising_id))/COUNT(distinct uuid) END :: DOUBLE PRECISION AS percentage_without_advertising_id
FROM ad_engagements ae 
LEFT OUTER JOIN campaigns c 
ON ae.campaign_id = c.id
LEFT OUTER JOIN ad_networks an 
ON c.ad_network_id = an.id
LEFT OUTER JOIN apps a 
ON c.app_id = a.id
WHERE c.ad_network_id = '@AD_NETWORK_ID' AND created_at >= '@START_DATE' and created_at < '@END_DATE'
AND event_type = 'click' AND a.bundle_id = '@BUNDLEID'
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4