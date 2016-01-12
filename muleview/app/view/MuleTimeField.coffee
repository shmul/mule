Ext.define "Muleview.view.MuleTimeField",
  requires: [
    "Ext.tip.ToolTip"
  ]
  alias: "widget.muletimefield"
  extend: "Ext.form.field.Text"
  regex: /^(-1s?)|([0-9]+[mhsdy]?)$/
  toolTipHtml: "
    You can use Mule's time format. <br/>
    <u>Examples:</u><br/>
    <ul>
      <li>  20s</li>
      <li>  5m</li>
      <li>  3h</li>
    </ul>
        "
  initComponent: ->
    this.on
      afterrender: () =>
        @createTip()
    @callParent()

  validator: (value) ->
    try
      seconds = Muleview.model.Retention.getMuleTimeValue(value)
      return seconds > -1
    catch e
      "Invalid input"

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
