Ext.define "Muleview.view.Theme",
  alternateClassName: ["Ext.chart.theme.Muleview"]
  extend: "Ext.chart.theme.Base"
  constructor: (config) ->
    Ext.chart.theme.Base.prototype.constructor.call(this, Ext.apply({
      # Colors stolen from http://designshack.net/articles/inspiration/10-free-color-palettes-from-10-famous-paintings/
      colors: [
        "#415E79"
        "#637771"
        "#E0C797"
        "#B78E5D"
        "#684F2C"
        "#011640"
        "#2D5873"
        "#7BA696"
        "#BFBA9F"
        "#BF9663"
        "#345573"
        "#6085A6"
        "#4C6F73"
        "#6F8C51"
        "#F2DC6D"
        "#514264"
        "#527E8E"
        "#8DB0A7"
        "#989A55"
        "#255C3F"
        "#3C535E"
        "#252D2A"
        "#F9D882"
        "#3F422E"
        "#261901"
        "#0F0B26"
        "#522421"
        "#8C5A2E"
        "#BF8641"
        "#B3B372"
      ]
    }, config))
