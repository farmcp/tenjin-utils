  /* This is a query to calculate click to install time(secs) for each ad-network, campaign, country, and site
@START_DATE => refers to the start date that you want to see the data for.
@END_DATE => refers to the end date that you want to see the data for.
@BUNDLEID => bundle_id of your app
@PLATFORM => platform of your app
*/
SELECT e.app_name, e.platform, e.network_name, e.campaign_name, e.country, e.site_id, datediff(sec, clicked_at, acquired_at) as diff, count(*) as count 
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
  WHERE e.event = 'open' AND c.ad_network_id NOT IN (0,3,5) AND acquired_at >= '@START_DATE' and acquired_at < '@END_DATE'
  AND e.bundle_id = '@BUNDLEID' AND e.platform = '@PLATFORM'
  GROUP BY 1,2,3,4,5,6,7,8
) AS e
JOIN (
  SELECT app_id, uuid, max(created_at) as clicked_at
  FROM ad_engagements 
  WHERE event_type = 'click' AND dateadd('day',7,created_at) >= '@START_DATE' AND bundle_id = '@BUNDLEID' AND platform = '@PLATFORM'
  GROUP BY 1,2
) AS ae
ON e.source_uuid = ae.uuid AND e.app_id = ae.app_id
WHERE datediff(sec, clicked_at, acquired_at) >= 0 AND datediff(sec, clicked_at, acquired_at) <= 120
GROUP BY 1,2,3,4,5,6,7