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

  # Returns child keys for the given parent
  getSubKeys: (parent, depth, callback) ->
    @askMule "key/#{parent}?level=#{depth}", (retentions)->
      keys = {}
      for ret in retentions
        key = ret.substring(0, ret.indexOf(";"))
        keys[key] = true
      callback(keyName for own keyName of keys)

  # Returns all mule's "graph" data for a given key,
  # In the form of "retention => key => data array" double-hash
  # Also returns the alerts in the form "key;retention" => array
  # Also throws a keysReceived event with all the given keys - so that the keys store will update
  getKeyData: (key, callback) ->
    @askMule "graph/#{key}?alerts=true", (response) =>
      keys = []
      keyData = {}
      alerts = null
      for own name, data of response
        if name == "alerts"
          alerts = data
        else
          [key, retention] = name.split(";")
          keys.push key
          keyData[retention] ||= {}
          keyData[retention][key] = data
      Muleview.event "keysReceived", keys
      callback(keyData, alerts)

  getKeysData: (keys, callback) ->
    callbacks = keys.length
    allKeys = {}
    counterCallback = (moreKeys) ->
      console.log('Mule.coffee\\ 51: arguments:', arguments);
      console.log('Mule.coffee\\ 52: callbacks:', callbacks);
      Ext.merge(allKeys, moreKeys)
      callbacks -= 1
      if callbacks == 0
        callback(allKeys)
    @getKeyData(key, counterCallback) for key in keys
