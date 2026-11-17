--!nonstrict
-- Frosted telemetry settings panel (A/B round 10). Spec: claude/spec-frosted-settings.md.
--
-- Tabs LOOK · BAR · MSGS · NIGHT · PLUGINS. Values are read with noctalia.getSetting()
-- and written with `noctalia msg config-set <path> <toml>` (plugins can't write config
-- directly). Noctalia stores those writes in its own settings.toml, and onConfigChanged()
-- re-renders when a value we read changes. Text values must be TOML-quoted; numbers,
-- booleans and arrays go in raw. Noctalia clamps numbers to its own ranges.

local ACC = "primary"
local ON_ACC = "on_primary"
local CLEAR = "#00000000" -- retained controls keep old props, so "no fill" must be explicit
local TXT = "on_surface"
local MUTED = "on_surface_variant"
local DIM = "on_surface/0.38"
local EDGE = "on_surface/0.16"
local TRACK = "on_surface/0.12"
local SMALL = 11
local SEGMENTS = 16
local SELF = "kunu/telemetry"
local DRAG = "ft-widget"

local TABS = { "LOOK", "BAR", "MSGS", "NIGHT", "PLUGINS" }

-- Built-in bar widget types Noctalia accepts by name (underscore spelling).
-- custom_button, scripted and text need their own [widget.x] table, so they're left out.
local BUILTINS = {
  "active_window", "audio_visualizer", "battery", "bluetooth", "brightness", "caffeine",
  "clipboard", "clock", "control_center", "keyboard_layout", "launcher", "lock_keys", "media",
  "network", "nightlight", "notifications", "power_profile", "privacy", "screenshot", "session",
  "settings", "spacer", "sysmon", "taskbar", "theme_mode", "tray", "volume", "wallpaper",
  "weather", "workspaces",
}

local s = {
  open = false, tab = "LOOK",
  pending = {},        -- path -> value written but not yet echoed back by getSetting
  plugins = nil, pluginsBusy = false,
  dnd = nil,
  sel = nil,           -- { lane = "end", i = 3 } selected bar chip
  adding = nil,        -- lane that the add-widget picker is open for
  status = nil,        -- last write error, shown in the footer
}

-- ── helpers ────────────────────────────────────────────────────────────────

local function label(text, color, extra)
  local props = { text = text, color = color or TXT }
  if extra then for k, v in pairs(extra) do props[k] = v end end
  return ui.label(props)
end

local function upper(name)
  return string.upper((string.gsub(name, "[_-]", " ")))
end

local function get(path)
  local p = s.pending[path]
  if p ~= nil then return p end
  return noctalia.getSetting(path)
end

local function toml(value)
  local t = type(value)
  if t == "boolean" then return value and "true" or "false" end
  if t == "number" then
    if value == math.floor(value) then return tostring(math.floor(value)) end
    return (string.gsub(string.format("%.3f", value), "0+$", ""))
  end
  if t == "table" then
    local parts = {}
    for i, v in ipairs(value) do parts[i] = toml(v) end
    return "[" .. table.concat(parts, ", ") .. "]"
  end
  return '"' .. string.gsub(tostring(value), '(["\\])', "\\%1") .. '"'
end

local render -- forward

local function set(path, value)
  s.pending[path] = value
  s.status = nil
  render()
  noctalia.runAsync({ "noctalia", "msg", "config-set", path, toml(value) }, function(r)
    if r.exitCode ~= 0 or string.find(r.stdout or "", "error", 1, true) then
      s.status = "WRITE FAILED: " .. path
      noctalia.log("config-set failed for " .. path .. ": " .. (r.stdout or "") .. (r.stderr or ""))
    end
    s.pending[path] = nil
    render()
  end)
end

local function ipc(argv, after)
  local cmd = { "noctalia", "msg" }
  for _, a in ipairs(argv) do table.insert(cmd, a) end
  noctalia.runAsync(cmd, function(r) if after then after(r) end end)
end

-- ── controls ───────────────────────────────────────────────────────────────

local function group(title, tag)
  return ui.row({ align = "center", gap = 6, paddingV = 2 }, {
    label(title, ACC),
    ui.box({ height = 1, flexGrow = 1, fill = "primary/0.45" }),
    label(tag, DIM, { fontSize = SMALL }),
  })
end

local function bracket(on)
  if on == true then return label("[■]", ACC) end
  if on == false then return label("[ ]", DIM) end
  return label("[-]", DIM)
end

local function toggle(name, path)
  local v = get(path)
  return ui.row({ key = "t-" .. path, align = "center", gap = 8, onClick = function()
    if v == nil then return end
    set(path, not v)
  end }, { bracket(v), label(name, TXT, { flexGrow = 1 }) })
end

-- options: array of { value, label }
local function cycle(name, path, options)
  local v = get(path)
  local idx = nil
  for i, o in ipairs(options) do if o[1] == v then idx = i end end
  local shown = idx and options[idx][2] or (v ~= nil and upper(tostring(v)) or "--")
  local function step(d)
    local i = ((idx or 1) - 1 + d) % #options + 1
    set(path, options[i][1])
  end
  return ui.row({ key = "c-" .. path, align = "center", gap = 4 }, {
    label(name, MUTED, { flexGrow = 1 }),
    ui.row({ paddingH = 4, onClick = function() step(-1) end }, { label("‹", DIM) }),
    label(shown, v ~= nil and ACC or DIM, { width = 112, textAlign = "center" }),
    ui.row({ paddingH = 4, onClick = function() step(1) end }, { label("›", DIM) }),
  })
end

-- Segmented number: 16 blocks spanning [min, max]; click a block to set it.
local function blocks(name, path, min, max, stepSize, fmt)
  local v = get(path)
  local lit = 0
  if type(v) == "number" then
    lit = math.floor((math.clamp(v, min, max) - min) / (max - min) * SEGMENTS + 0.5)
  end
  local segs = {}
  for i = 1, SEGMENTS do
    local target = min + (max - min) * i / SEGMENTS
    target = math.floor(target / stepSize + 0.5) * stepSize
    segs[i] = ui.box({
      key = path .. "#" .. i, height = 10, flexGrow = 1, radius = 1,
      fill = (i <= lit) and ACC or TRACK,
      onClick = function() set(path, target) end,
    })
  end
  return ui.column({ key = "b-" .. path, gap = 4 }, {
    ui.row({ align = "center" }, {
      label(name, MUTED, { flexGrow = 1 }),
      label(type(v) == "number" and fmt(v) or "--", type(v) == "number" and ACC or DIM),
    }),
    ui.row({ gap = 2 }, segs),
  })
end

local function nav(name, value, onClick)
  return ui.row({ key = "n-" .. name, align = "center", gap = 8, onClick = onClick }, {
    label(name, TXT, { flexGrow = 1 }),
    label(value or "", MUTED),
    ui.glyph({ name = "chevron-right", size = 14, color = DIM }),
  })
end

-- ── bar lanes ──────────────────────────────────────────────────────────────

local LANES = { { "start", "START" }, { "center", "CENTER" }, { "end", "END" } }

local function laneList(lane)
  local v = get("bar.main." .. lane)
  local out = {}
  if type(v) == "table" then for i, name in ipairs(v) do out[i] = name end end
  return out
end

local function writeLane(lane, list)
  s.sel, s.adding = nil, nil
  set("bar.main." .. lane, list)
end

local function chipWidth(name) return #name * 7 + 14 end

-- Wraps chips into rows that fit the lane (≈ 320 px inside a 380 px panel).
local function wrap(nodes, widths, maxWidth)
  local rows, row, used = {}, {}, 0
  for i, node in ipairs(nodes) do
    local w = widths[i] + 4
    if used + w > maxWidth and #row > 0 then
      table.insert(rows, ui.row({ gap = 4 }, row))
      row, used = {}, 0
    end
    table.insert(row, node)
    used += w
  end
  if #row > 0 then table.insert(rows, ui.row({ gap = 4 }, row)) end
  return rows
end

local function chip(text, active, outlined)
  return ui.row({
    paddingH = 5, paddingV = 1, radius = 5, borderWidth = 1,
    fill = active and ACC or CLEAR,
    border = active and ACC or (outlined and EDGE or CLEAR),
  }, { label(text, active and ON_ACC or TXT, { fontSize = SMALL }) })
end

function onWidgetDrop(payload, target)
  local fromLane, fromIdx = string.match(payload, "^(%a+)|(%d+)$")
  local toLane, toPos = string.match(target, "^(%a+)|(%w+)$")
  if not fromLane or not toLane then return end
  fromIdx = tonumber(fromIdx)
  local src = laneList(fromLane)
  local name = table.remove(src, fromIdx)
  if not name then return end
  local dst = (fromLane == toLane) and src or laneList(toLane)
  local at = (toPos == "end") and (#dst + 1) or tonumber(toPos)
  if fromLane == toLane and toPos ~= "end" and fromIdx < at then at -= 1 end
  table.insert(dst, math.clamp(at, 1, #dst + 1), name)
  if fromLane ~= toLane then writeLane(fromLane, src) end
  writeLane(toLane, dst)
end

local function laneNode(lane, title)
  local names = laneList(lane)
  local nodes, widths = {}, {}
  for i, name in ipairs(names) do
    local selected = s.sel and s.sel.lane == lane and s.sel.i == i
    local text = upper(name)
    nodes[i] = ui.dropZone({ key = "dz-" .. lane .. i, accepts = { DRAG }, value = lane .. "|" .. i, onDrop = "onWidgetDrop", direction = "row" }, {
      ui.dragSource({
        key = "ds-" .. lane .. i, dragType = DRAG, payload = lane .. "|" .. i, grabCursor = false,
        onClick = function()
          if selected then s.sel = nil else s.sel = { lane = lane, i = i } end
          s.adding = nil
          render()
        end,
      }, { chip(text, selected, not selected) }),
    })
    widths[i] = chipWidth(text)
  end
  table.insert(nodes, ui.row({ key = "add-" .. lane, paddingH = 5, paddingV = 1, onClick = function()
    s.adding = (s.adding == lane) and nil or lane
    s.sel = nil
    render()
  end }, { label(s.adding == lane and "−" or "+", s.adding == lane and ACC or DIM, { fontSize = SMALL }) }))
  table.insert(widths, 20)

  return ui.column({ key = "lane-" .. lane, gap = 3 }, {
    ui.row({ align = "center" }, {
      label(title, DIM, { fontSize = SMALL, flexGrow = 1 }),
      label(string.format("%02d", #names), DIM, { fontSize = SMALL }),
    }),
    ui.dropZone({
      key = "zone-" .. lane, accepts = { DRAG }, value = lane .. "|end", onDrop = "onWidgetDrop",
      direction = "column", gap = 4, padding = 4, radius = 6, border = EDGE, borderWidth = 1, hitSlop = 6,
    }, wrap(nodes, widths, 318)),
  })
end

local function selectedActions()
  if not s.sel then return nil end
  local list = laneList(s.sel.lane)
  local name = list[s.sel.i]
  if not name then s.sel = nil; return nil end
  local function move(d)
    local j = s.sel.i + d
    if j < 1 or j > #list then return end
    list[s.sel.i], list[j] = list[j], list[s.sel.i]
    local lane = s.sel.lane
    writeLane(lane, list)
    s.sel = { lane = lane, i = j }
  end
  local function act(text, fn, color)
    return ui.row({ paddingH = 4, onClick = fn }, { label(text, color or MUTED) })
  end
  return ui.row({ key = "sel-actions", align = "center", gap = 6 }, {
    label(upper(name), ACC, { flexGrow = 1 }),
    act("[‹]", function() move(-1) end),
    act("[›]", function() move(1) end),
    act("[✕]", function()
      table.remove(list, s.sel.i)
      writeLane(s.sel.lane, list)
    end, "error"),
  })
end

local function candidates()
  local used = {}
  for _, l in ipairs(LANES) do for _, n in ipairs(laneList(l[1])) do used[n] = true end end
  local seen, out = {}, {}
  local function add(n) if not used[n] and not seen[n] then seen[n] = true; table.insert(out, n) end end
  for _, n in ipairs(BUILTINS) do add(n) end
  local instances = noctalia.getSetting("widget")
  if type(instances) == "table" then for name in pairs(instances) do add(name) end end
  table.sort(out)
  return out
end

local function picker()
  if not s.adding then return nil end
  local lane = s.adding
  local nodes, widths = {}, {}
  for i, name in ipairs(candidates()) do
    local text = upper(name)
    nodes[i] = ui.row({ key = "pick-" .. name, onClick = function()
      local list = laneList(lane)
      table.insert(list, name)
      writeLane(lane, list)
    end }, { chip(text, false, true) })
    widths[i] = chipWidth(text)
  end
  local rows = wrap(nodes, widths, 330)
  table.insert(rows, 1, label("ADD TO " .. string.upper(lane), DIM, { fontSize = SMALL }))
  return ui.column({ key = "picker", gap = 4 }, rows)
end

-- ── plugins ────────────────────────────────────────────────────────────────

local function readPlugins()
  s.pluginsBusy = true
  ipc({ "plugins", "list" }, function(r)
    s.pluginsBusy = false
    if r.exitCode ~= 0 then s.plugins = nil; render(); return end
    local list = {}
    for line in string.gmatch(r.stdout or "", "[^\n]+") do
      local id, src, ver, state = string.match(line, "^(%S+) %[(.-)%] (%S+) (%a+)")
      if id then table.insert(list, { id = id, source = src, version = ver, enabled = state == "enabled" }) end
    end
    table.sort(list, function(a, b)
      if a.enabled ~= b.enabled then return a.enabled end
      return a.id < b.id
    end)
    s.plugins = list
    render()
  end)
end

local function pluginRows()
  local rows = {}
  if s.plugins == nil then
    table.insert(rows, label(s.pluginsBusy and "SCANNING ▁▂▄" or "NO SIGNAL", DIM))
    return rows
  end
  for i, p in ipairs(s.plugins) do
    if i > 12 then table.insert(rows, label(string.format("+%d MORE IN ALL SETTINGS", #s.plugins - 12), DIM, { fontSize = SMALL })); break end
    local own = p.id == SELF
    table.insert(rows, ui.row({ key = "p-" .. p.id, align = "center", gap = 8, onClick = function()
      if own then return end
      ipc({ "plugins", p.enabled and "disable" or "enable", p.id }, readPlugins)
    end }, {
      bracket(p.enabled),
      label(p.id, p.enabled and ACC or TXT, { flexGrow = 1, maxLines = 1 }),
      label(own and "SELF" or p.version, DIM, { fontSize = SMALL }),
    }))
  end
  return rows
end

-- ── tabs ───────────────────────────────────────────────────────────────────

local function readDnd()
  ipc({ "notification-dnd-status" }, function(r)
    if r.exitCode == 0 then s.dnd = string.find(string.lower(r.stdout or ""), "on", 1, true) ~= nil else s.dnd = nil end
    render()
  end)
end

local function kelvin(v) return string.format("%d K", math.floor(v + 0.5)) end
local function px(v) return string.format("%d PX", math.floor(v + 0.5)) end
local function pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function times(v) return string.format("×%.2f", v) end

local SCHEMES = {
  { "m3-content", "M3 CONTENT" }, { "m3-tonal-spot", "TONAL SPOT" }, { "muted", "MUTED" },
  { "faithful", "FAITHFUL" }, { "vibrant", "VIBRANT" }, { "m3-fruit-salad", "FRUIT SALAD" },
  { "m3-rainbow", "RAINBOW" }, { "m3-monochrome", "MONOCHROME" },
}
local POSITIONS = {
  { "top_center", "TOP CENTER" }, { "top_right", "TOP RIGHT" }, { "top_left", "TOP LEFT" },
  { "bottom_center", "BOTTOM CENTER" }, { "bottom_right", "BOTTOM RIGHT" }, { "bottom_left", "BOTTOM LEFT" },
}

local function tabLook()
  return {
    group("THEME", "L-01"),
    cycle("MODE", "theme.mode", { { "dark", "DARK" }, { "light", "LIGHT" }, { "auto", "AUTO" } }),
    cycle("SCHEME", "theme.wallpaper_scheme", SCHEMES),
    cycle("PANELS", "shell.panel.transparency_mode", { { "glass", "GLASS" }, { "soft", "SOFT" }, { "solid", "SOLID" } }),
    toggle("GLASS SETTINGS WINDOW", "shell.settings_window_translucent"),
    group("MOTION", "L-02"),
    toggle("ANIMATIONS", "shell.animation.enabled"),
    blocks("SPEED", "shell.animation.speed", 0.25, 2.0, 0.05, times),
    group("WALLPAPER", "L-03"),
    nav("WALLPAPER", "PICKER", function() panel.close(); ipc({ "panel-open", "wallpaper" }) end),
  }
end

local function tabBar()
  local out = {
    group("GEOMETRY", "B-01"),
    blocks("THICKNESS", "bar.main.thickness", 24, 56, 2, px),
    blocks("OPACITY", "bar.main.background_opacity", 0, 1, 0.05, pct),
    toggle("AUTO-HIDE", "bar.main.auto_hide"),
    group("WIDGETS", "B-02"),
  }
  for _, l in ipairs(LANES) do table.insert(out, laneNode(l[1], l[2])) end
  local actions = selectedActions()
  if actions then table.insert(out, actions) end
  local pick = picker()
  if pick then table.insert(out, pick) end
  if not actions and not pick then
    table.insert(out, label("DRAG TO MOVE · CLICK TO EDIT · + TO ADD", DIM, { fontSize = SMALL }))
  end
  return out
end

local function tabMsgs()
  return {
    group("TOASTS", "M-01"),
    cycle("POSITION", "notification.position", POSITIONS),
    blocks("OPACITY", "notification.background_opacity", 0, 1, 0.05, pct),
    toggle("APP NAME", "notification.show_app_name"),
    toggle("ACTIONS", "notification.show_actions"),
    toggle("GROUP BY APP", "notification.group_by_app"),
    group("QUIET", "M-02"),
    ui.row({ key = "dnd", align = "center", gap = 8, onClick = function() ipc({ "notification-dnd-toggle" }, readDnd) end }, {
      bracket(s.dnd), label("QUIET NOW", TXT, { flexGrow = 1 }),
    }),
  }
end

local function tabNight()
  return {
    group("NIGHT LIGHT", "N-01"),
    toggle("SCHEDULE", "nightlight.enabled"),
    blocks("DAY", "nightlight.temperature_day", 1000, 6500, 50, kelvin),
    blocks("NIGHT", "nightlight.temperature_night", 1000, 6500, 50, kelvin),
  }
end

local function tabPlugins()
  local out = { group("INSTALLED", "P-01") }
  for _, row in ipairs(pluginRows()) do table.insert(out, row) end
  return out
end

-- ── frame ──────────────────────────────────────────────────────────────────

local function header()
  local chips = {}
  for i, t in ipairs(TABS) do
    local active = t == s.tab
    chips[i] = ui.row({
      key = "tab-" .. t, paddingH = 6, paddingV = 2, radius = 5, borderWidth = 1,
      fill = active and ACC or CLEAR, border = active and ACC or EDGE,
      onClick = function()
        s.tab, s.sel, s.adding = t, nil, nil
        if t == "PLUGINS" then readPlugins() elseif t == "MSGS" then readDnd() end
        render()
      end,
    }, { label(t, active and ON_ACC or MUTED, { fontSize = SMALL }) })
  end
  return ui.column({ gap = 6 }, {
    ui.row({ align = "center" }, {
      label("CFG // SETTINGS", ACC, { flexGrow = 1 }),
      label("FT-02", DIM, { fontSize = SMALL }),
    }),
    ui.box({ height = 1, fill = "primary/0.7" }),
    ui.row({ gap = 4 }, chips),
  })
end

local function settingsFile()
  local base = noctalia.getenv("NOCTALIA_STATE_HOME") or noctalia.getenv("XDG_STATE_HOME")
  base = base and (base .. "/noctalia") or noctalia.expandPath("~/.local/state/noctalia")
  return base .. "/settings.toml"
end

local function footer()
  local dots = {}
  for i, t in ipairs(TABS) do
    local on = t == s.tab
    dots[i] = ui.box({ key = "dot-" .. t, width = 6, height = 6, radius = 1, borderWidth = 1,
      fill = on and ACC or CLEAR, border = on and ACC or DIM })
  end
  local info = noctalia.fileInfo(settingsFile())
  local sync = info and os.date("%H:%M", info.mtime) or "--:--"
  local row = { ui.row({ gap = 5, align = "center" }, dots) }
  table.insert(row, label(s.status or ("SYNC " .. sync), s.status and "error" or DIM, { fontSize = SMALL, flexGrow = 1, textAlign = "center" }))
  table.insert(row, label("T+" .. string.format("%03d", os.date("*t").yday), DIM, { fontSize = SMALL }))
  return ui.column({ gap = 8 }, {
    ui.box({ height = 1, fill = TRACK }),
    nav("ALL SETTINGS", "", function() panel.close(); ipc({ "settings-open" }) end),
    ui.row({ align = "center", gap = 8 }, row),
  })
end

render = function()
  if not s.open then return end
  local body
  if s.tab == "BAR" then body = tabBar()
  elseif s.tab == "MSGS" then body = tabMsgs()
  elseif s.tab == "NIGHT" then body = tabNight()
  elseif s.tab == "PLUGINS" then body = tabPlugins()
  else body = tabLook() end
  panel.render(ui.column({ gap = 12 }, {
    header(),
    ui.column({ gap = 9 }, body),
    footer(),
  }))
end

-- ── lifecycle ──────────────────────────────────────────────────────────────

function onOpen(context)
  s.open, s.sel, s.adding, s.status = true, nil, nil, nil
  if context and context ~= "" then
    local t = string.upper(context)
    for _, name in ipairs(TABS) do if name == t then s.tab = t end end
  end
  if s.tab == "PLUGINS" then readPlugins() elseif s.tab == "MSGS" then readDnd() end
  render()
end

function onClose()
  s.open = false
end

function onConfigChanged()
  render()
end

-- noctalia msg plugin kunu/telemetry:settings all <event> [payload]
--   tab <look|bar|msgs|night|plugins> · select <lane> <i> · add <lane> · drop <lane>:<i> <lane>:<i|end>
function onIpc(event, payload)
  if not s.open then return end
  if event == "tab" and payload then
    local t = string.upper(payload)
    for _, name in ipairs(TABS) do if name == t then s.tab = t end end
    s.sel, s.adding = nil, nil
    if s.tab == "PLUGINS" then readPlugins() elseif s.tab == "MSGS" then readDnd() end
  elseif event == "select" and payload then
    local lane, i = string.match(payload, "^(%a+)%s+(%d+)$")
    if lane then s.sel, s.adding = { lane = lane, i = tonumber(i) }, nil end
  elseif event == "add" and payload then
    s.adding, s.sel = payload, nil
  elseif event == "drop" and payload then
    -- Same path as a drag: "drop <fromLane>:<i> <toLane>:<i|end>"
    local from, to = string.match(payload, "^(%S+)%s+(%S+)$")
    if from then onWidgetDrop((string.gsub(from, ":", "|")), (string.gsub(to, ":", "|"))) end
  end
  render()
end
