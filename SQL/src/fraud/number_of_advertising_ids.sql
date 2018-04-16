/* % of advertising_ids with more than 1 click.
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@AD_NETWORK_ID => ID of ad-network
*/
SELECT name AS app_name, platform, network_name, click_count, COUNT(*) AS count 
FROM (
  SELECT advertising_id, site_id, a.name, a.platform, an.name AS network_name, COUNT(*) AS click_count
  FROM ad_engagements ae 
  LEFT OUTER JOIN campaigns c 
  ON ae.campaign_id = c.id
  LEFT OUTER JOIN ad_networks an 
  ON c.ad_network_id = an.id
  LEFT OUTER JOIN apps a 
  ON c.app_id = a.id
  WHERE c.ad_network_id = '@AD_NETWORK_ID' AND created_at >= '@START_DATE' and created_at < '@END_DATE'
  AND a.bundle_id = '@BUNDLEID'
  GROUP BY 1,2,3,4,5
) sq
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4