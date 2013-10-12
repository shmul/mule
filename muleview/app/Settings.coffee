Ext.define "Muleview.Settings",
  singleton: true

  # Mule Prefix:
  muleUrlPrefix: "api/" # Base URL to Mule

  # Retries
  muleRequestRetries: 3 # How much retries to do when failing to get response from Mule

  # Update Intervals:
  updateInterval: 1000 * 60 * 5 # Graph auto-refresh rate (millis)
  alertsReportUpdateInterval: 1000 * 60 * 1 # Alerts Report auto-refresh rate (millis)

  # Graph Label Formats:
  labelTimeFormat: "H:i" # Graph label time format, see http://docs.sencha.com/ext-js/4-2/#!/api/Ext.Date for formatting options
  labelDateFormat: "d/m/y" # Graph label date format, see above
