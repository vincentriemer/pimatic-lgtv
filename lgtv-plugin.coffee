# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Include you own depencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #
  lgtv = require 'webos'
  Remote = lgtv.Remote
  Scanner = lgtv.Scanner

  delay = (ms, func) -> setTimeout func, ms

  # ###MyPlugin class
  # Create a class that extends the Plugin class and implements the following functions:
  class MyPlugin extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      # get the device config schemas
      deviceConfigDef = require("./device-config-schema")
      env.logger.info("Starting pimatic-lgtv plugin")

      @framework.deviceManager.registerDeviceClass("LGTVAppButtonsDevice", {
        configDef: deviceConfigDef.LGTVAppButtonsDevice,
        createCallback: (config, lastState) =>
          return new LGTVAppButtonsDevice(config, @)
      })

      @framework.deviceManager.on 'discover', () =>
        env.logger.debug("Starting discovery")
        @framework.deviceManager.discoverMessage(
          'pimatic-lgtv', "Searching for TVs"
        )

        scanner = new Scanner()
        scanner.startScanning()
        scanner.on 'device', (device) =>
          tvIp = device.address

          remote = new Remote()
          remote.connect { address: tvIp }, (err, newKey) =>
            deviceConfig =
              class: "LGTVAppButtonsDevice"
              name: device.friendlyName
              id: "lgtv-apps"
              tvIp: tvIp
              key: newKey

            remote.getApps (results) =>
              buttons = []

              for app in results
                name = app.title
                appId = app.id
                
                buttonConfig =
                  id: "#{name.toLowerCase().replace(" ", "-")}-button"
                  text: "Launch #{name}"
                  appId: appId
                
                buttons.push buttonConfig
              
              deviceConfig.buttons = buttons
              @framework.deviceManager.discoveredDevice(
                'pimatic-lgtv', "#{deviceConfig.name}", deviceConfig
              )
              remote.disconnect()
              scanner.stopScanning()

  class LGTVAppButtonsDevice extends env.devices.ButtonsDevice
    constructor: (@config, @plugin) ->
      @name = @config.name
      @id = @config.id
      @tvIp = @config.tvIp
      @key = @config.key
      @buttons = @config.buttons

      # @remote.connect { address: @tvIp, key: @key }, (err) =>
      #   env.logger.info(err)

      super(@config)
    
    destroy: () ->
      remote.disconnect()
      super()

    retryAppLaunch: (retryCount, appId, resolve, reject, remote) ->
      env.logger.info("retrying launching #{appId}")
      delay 2000, =>
        remote.disconnect =>
          @launchApp retryCount + 1, appId, resolve, reject

    launchApp: (retryCount, appId, resolve, reject) ->
      if retryCount > 6
        return reject("Failed attempting to launch #{appId}")

      remote = new Remote { }

      remote.connect { address: @tvIp, key: @key }, (err) =>
        if err
          reject('error connecting to lgtv')
          # @retryAppLaunch retryCount, appId, resolve, reject, remote
        else
          remote.openApp appId, null, (err) =>
            if err
              reject('error opening app on lgtv')
              # @retryAppLaunch retryCount, appId, resolve, reject, remote
            else
              remote.disconnect =>
                resolve()
    
    buttonPressed: (buttonId) ->
      return new Promise (resolve, reject) =>
        for b in @config.buttons
          if b.id is buttonId
            @emit 'button', b.id
            @launchApp(0, b.appId, resolve, reject)

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new MyPlugin
  # and return it to the framework.
  return myPlugin