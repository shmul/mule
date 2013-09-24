Ext.define "Muleview.Mule",
  singleton: true
  getAlertCommandUrl: (key, retention) ->
    @prefix() + "alert/#{key};#{retention}"

  prefix: ->
    Muleview.Settings.muleUrlPrefix

  # General method to query mule
  askMule: (command, fn) ->
    eventId = Ext.id()
    Muleview.event "commandSent", command, eventId
    Ext.Ajax.request
      url: @prefix() + command
      timeout: 10 * 60 * 1000 # 10 minutes
      success: (response) =>
        Muleview.event "commandReceived", command, eventId, true
        fn(JSON.parse(response.responseText).data)
      failure: =>
        Muleview.event "commandReceived", command, eventId, false

  # Returns a hash of all child keys for the given parent and a flag specifying if they have subkeys
  getSubKeys: (parent, depth, callback) ->
    @askMule "key/#{parent}?level=#{depth}", (retentions)->
      keys = {}
      for ret, data of retentions
        key = ret.substring(0, ret.indexOf(";"))
        keys[key] = data.childs
      callback(keys)

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
    allAlerts = {}
    counterCallback = (moreKeys, moreAlerts) ->
      Ext.merge(allKeys, moreKeys)
      Ext.merge(allAlerts, moreAlerts)
      callbacks -= 1
      if callbacks == 0
        callback(allKeys, allAlerts)
    @getKeyData(key, counterCallback) for key in keys
