local app = {}

app.menubar = hs.menubar.new()
app.wf = hs.window.filter.new()

local presets = {
  { label = "800p (1422×800)", w = 1422, h = 800 },
  { label = "1080p (1920×1080)", w = 1920, h = 1080 },
  { label = "1440p (2560×1440)", w = 2560, h = 1440 },
}

app.lastWin = nil

app.wf:subscribe(hs.window.filter.windowFocused, function(win)
  app.lastWin = win
end)

local function targetWindow()
  if app.lastWin and app.lastWin:isStandard() and app.lastWin:application() then
    return app.lastWin
  end

  local win = hs.window.focusedWindow() or hs.window.frontmostWindow()
  if win and win:isStandard() and win:application() then
    return win
  end

  return nil
end

local function resizeWindow(w, h)
  local win = targetWindow()

  if not win then
    hs.alert.show("No focused window")
    return
  end

  win:setSize(hs.geometry.size(w, h))
  win:focus()
end

local function buildMenu()
  local items = {}

  for _, p in ipairs(presets) do
    table.insert(items, {
      title = p.label,
      fn = function() resizeWindow(p.w, p.h) end,
    })
  end

  return items
end

app.menubar:setMenu(buildMenu)
app.menubar:setTitle("⧉")

return app
