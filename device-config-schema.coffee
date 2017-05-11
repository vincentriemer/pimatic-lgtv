module.exports = {
  title: "pimatic-lgtv device config schema"
  LGTVAppButtonsDevice: {
    title: "LGTVButtonsDevice config options"
    type: "object"
    properties:
      tvIp:
        description: "IP of your LGTV"
        type: "string"
      key:
        description: "Unique key identifying your pimatic instance to the LG TV"
        type: "string"
      buttons:
        description: "LGTV App buttons to display"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            id:
              type: "string"
            text:
              type: "string"
            appId:
              description: "ID of the app on your LGTV"
              type: "string"
  }
}