Ext.define "Muleview.Mule",
  requires: [
    "Muleview.Settings"
  ]

  singleton: true
  getAlertCommandUrl: (key, retention) ->
    @prefix() + "alert/#{key};#{retention}"

  prefix: ->
    Muleview.Settings.muleUrlPrefix

  # General method to query mule
  askMule: (command, fn) ->
    successFn = failureFn = askFn = null
    attempt = 0
    eventId = Ext.id()

    askFn = () =>
      try
        Ext.Ajax.request
          url: @prefix() + command
          timeout: 10 * 60 * 1000 # 10 minutes
          success: (response) => successFn(response)
          failure: => failureFn()
      catch error
        failureFn()

    failureFn = () =>
      attempt += 1
      if attempt < Muleview.Settings.muleRequestRetries
        # Exponential backoff:
        setTimeout ->
          Muleview.event "commandRetry", command, attempt
          askFn()
        , Math.pow(2, attempt - 1) * 1000
      else
        # Failed too many times :(
        Muleview.event "commandReceived", command, eventId, false

    successFn =  (response) =>
      Muleview.event "commandReceived", command, eventId, true
      try
        data =JSON.parse(response.responseText).data
      catch error
        console.error "Error while parsing response for Mule command: '#{command}'\n Response was: \n#{response.responseText}"
        failureFn()
      fn(data)

    Muleview.event "commandSent", command, eventId
    askFn()

  prepareData: (arr) ->
    Ext.Array.map arr, (record) ->
      {
        x: record[2]
        y: record[0]
        hits: record[1]
      }


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
    @askMule "graph/#{key};?level=0&alerts=false&filter=now", (response) =>
      retentions = {}
      for own name, data of response
        [keyName, retention] = name.split(";")
        retentions[retention] = @prepareData(data) if key == keyName
        #TODO: perhaps throw a warning if an invalid key was given, too

      for ret, data of retentions
        @sortData(data)
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

  # Receive data for a stacked graph, including alerts
  # Updates the alerts store as a side-effect
  getGraphData: (key, retention, callback) ->
    @askMule "graph/#{key};#{retention}?level=1&alerts=true&filter=now", (response) =>
      ans = {}
      alerts = response.alerts?[retention]
      delete response.alerts
      Ext.StoreManager.get("alertsStore").loadRawData({data: alerts}, "append")
      for name, data of response
        [key, ret] = name.split(";")
        throw "Invalid retention received: #{ret}" unless ret = retention
        data = @prepareData(data)
        @sortData(data)
        ans[key] = data
      callback(ans)

  getPieChartData: (key, retention, timestamp, callback) ->
    @askMule "graph/#{key};#{retention}?level=1&alerts=false&timestamp=#{timestamp}&count=999999", (response) ->
      ans = []
      topKeyTotal = null
      Ext.iterate response, (subkey, records) ->
        point = records[0]
        subkeyPath = subkey.split(".")
        lastSubkeyPath = subkeyPath.pop()
        if subkeyPath.join(".") == key && point
          ans.push({
            key: lastSubkeyPath.split(";")[0]
            value: point[0]
          })
        else if subkey == key + ";" + retention && point
          topKeyTotal = point[0]
      callback(ans, topKeyTotal)

  sortData: (dataArr) ->
    #TODO: something else?
    Ext.Array.sort dataArr, (a, b ) ->
      a.x - b.x
