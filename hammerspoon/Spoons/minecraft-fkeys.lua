local minecraftKeys = {}
local appWatcher = nil

local function enableMinecraftKeys()
  for i = 1, 12 do
    minecraftKeys[i] = hs.hotkey.bind({}, "f" .. i, function()
      hs.eventtap.keyStroke({}, "f" .. i, 0)
    end)
  end

  hs.alert.show("Function keys enabled")
end

local function disableMinecraftKeys()
  for i = 1, 12 do
    if minecraftKeys[i] then
      minecraftKeys[i]:delete()
      minecraftKeys[i] = nil
    end
  end

  hs.alert.show("Function keys disabled")
end

local function appWatcherFn(appName, eventType, app)
  if appName == "java" then
    if eventType == hs.application.watcher.activated then
      enableMinecraftKeys()
    elseif eventType == hs.application.watcher.deactivated then
      disableMinecraftKeys()
    end
  end
end

appWatcher = hs.application.watcher.new(appWatcherFn)
appWatcher:start()
