Ext.define "Muleview.Mule",
  singleton: true
  getAlertCommandUrl: (key, retention) ->
    @prefix() + "alert/#{key};#{retention}"

  prefix: ->
    Muleview.Settings.muleUrlPrefix

  # General method to query mule
  askMule: (command, fn) ->
    Muleview.event "commandSent", command
    Ext.Ajax.request
      url: @prefix() + command
      success: (response) =>
        Muleview.event "commandReceived", command
        fn(JSON.parse(response.responseText).data)

  # Return a nested hash of all possible keys
  getAllKeys: (callback)->
    ans = {}
    @askMule "key?deep=true", (keys) =>
      for key in keys
        arr = key.split(";")[0].split(".")
        node = ans
        until arr.length == 0
          current = arr.shift()
          node = (node[current] ||= {})
      callback(ans)

  # Returns all mule's "graph" data for a given key,
  # In the form of "retention => key => data array" double-hash
  # Also returns the alerts in the form "key;retention" => array
  getKeyData: (key, callback) ->
    @askMule "graph/#{key}?alerts=true", (response) =>
      keyData = {}
      alerts = null
      for own name, data of response
        if name == "alerts"
          alerts = data
        else
          [key, retention] = name.split(";")
          keyData[retention] ||= {}
          keyData[retention][key] = data
      callback(keyData, alerts)
