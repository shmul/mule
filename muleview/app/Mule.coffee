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
        keys[key] = data.children
      callback(keys)

  # For a given key, returns data per each retention
  # in the form of "retention => data array"
  getKeyData: (key, callback) ->
    @askMule "graph/#{key}?deep=false?alerts=false", (response) =>
      retentions = {}
      for own name, data of response
        [keyName, retention] = name.split(";")
        throw "Invalid key received: '#{keyName}'" unless key == keyName
        retentions[retention] = data
      callback(retentions)

  # For a list of keys, returns data per retention per key
  # in a double hash: retention => key => data
  # The method aggregates multiple asynch requests' data
  getKeysData: (keys, callback) ->
    callbacks = keys.length
    retentions = {}
    for key in keys
      do (key) =>
        @getKeyData key, (keyData) ->
          for ret, retData of keyData
            retentions[ret] ||= {}
            retentions[ret][key] = retData
          callbacks--
          callback(retentions) if callbacks == 0
