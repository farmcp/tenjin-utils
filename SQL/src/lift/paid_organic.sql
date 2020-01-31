SELECT date_trunc('day', date) ,
  sum(case when ad_networks.id = 0 then tracked_installs else null end) as organic_installs,
  sum(case when ad_networks.id <> 0 then tracked_installs else null end) as paid_installs
FROM tenjin.reporting_metrics
inner join campaigns
  ON campaigns.id = reporting_metrics.campaign_id
inner join ad_networks
  ON campaigns.ad_network_id = ad_networks.id
where date >= '@START_DATE' and date <= '@END_DATE' 
  and reporting_metrics.app_id = '@APP_ID'
GROUP BY 1
ORDER BY 1 DESC;
