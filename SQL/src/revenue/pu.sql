/* Calculate the ARPDAU of event revenue for a specific date. 
 * @BUNDLEID   - the bundle ID or package name of the app
 * @PLATFORM    - the platform of the app (ios, andorid, amazon)
 * @DATE        - the date of the calculation
*/

SELECT
  COUNT(DISTINCT(CASE WHEN event_type = 'purchase' AND purchase_state IN (0,3) THEN coalesce(advertising_id, developer_device_id) END)) AS pu,
  COUNT(DISTINCT(CASE WHEN event = 'open' AND acquired_at::date = created_at::date THEN coalesce(advertising_id, developer_device_id) END)) AS tracked_installs,
  COUNT(DISTINCT(CASE WHEN event_type = 'purchase' AND purchase_state IN (0,3) THEN coalesce(advertising_id, developer_device_id) END))/COUNT(DISTINCT(CASE WHEN event = 'open' AND acquired_at::date = created_at::date THEN coalesce(advertising_id, developer_device_id) END)) :: DOUBLE PRECISION AS pu_ratio
FROM events
WHERE created_at :: DATE = '@DATE'
  AND bundle_id = '@BUNDLEID'
  AND platform = '@PLATFORM';
