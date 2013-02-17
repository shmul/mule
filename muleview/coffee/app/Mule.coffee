Ext.define "Muleview.Mule",
  singleton: true

  # General method to query mule
  askMule: (command, fn) ->
    Ext.Ajax.request
      url: "mule/" + command
      success: (response) ->
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
