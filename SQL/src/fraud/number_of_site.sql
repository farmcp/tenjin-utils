/* Compare the total amount of site_ids per network.
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT a.name, a.platform, an.name AS network_name, COUNT(distinct site_id) AS site_count
FROM ad_engagements ae 
LEFT OUTER JOIN campaigns c 
ON ae.campaign_id = c.id
LEFT OUTER JOIN ad_networks an 
ON c.ad_network_id = an.id
LEFT OUTER JOIN apps a 
ON c.app_id = a.id
WHERE c.ad_network_id = '@AD_NETWORK_ID' AND created_at >= '@START_DATE' and created_at < '@END_DATE'
AND a.bundle_id = '@BUNDLEID'
GROUP BY 1,2,3
ORDER BY 1,2,3