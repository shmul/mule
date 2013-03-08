Ext.define "Muleview.view.MuleTimeField",
  alias: "widget.muletimefield"
  extend: "Ext.form.field.Text"
  regex: /^[0-9]+[mhsdy]?$/
  toolTipHtml: "
    You can use Mule's time format. <br/>
    <u>Examples:</u><br/>
    <ul>
      <li>  20s</li>
      <li>  5m</li>
      <li>  3h</li>
    </ul>
        "
  listeners:
    afterrender: (me) ->
      me.createTip()

  createTip: ->
    Ext.create "Ext.tip.ToolTip",
      anchorSize:
        height: 5
        width: 10
      anchorOffset: 10
      anchorToTarget: true
      defaultAlign: "r"
      target: @.getEl()
      html: @toolTipHtml
      title: "Mule Time Format"
      anchor: "left"
      dismissDelay: 0
