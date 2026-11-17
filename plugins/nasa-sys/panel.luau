--!nonstrict
-- NASA-SYS control panel (round 9 picks). Spec: claude/spec-nasa-sys-panel.md.
--
-- Data sources (never invented: unknown shows "--", missing tool shows "NO SIGNAL"):
--   NET      nmcli radio wifi / nmcli dev wifi list / connect
--   BT LINK  bluetoothctl show / devices Connected / power on|off
--   QUIET    noctalia msg notification-dnd-status|toggle
--   NIGHT    noctalia msg nightlight-force-toggle; Noctalia exposes no night-light state,
--            so the row shows [-] (unknown) rather than guessing
--   VOL      wpctl get-volume|set-volume|set-mute @DEFAULT_AUDIO_SINK@
--   BRT      brightnessctl -m / set N%
--   CPU/GPU/RAM noctalia.systemStats(), BAT from /sys/class/power_supply
-- Polls only while open: state every 5 s, clock/stats every second.

local ACC = "primary"
local ERR = "error"
local TXT = "on_surface"
local MUTED = "on_surface_variant"
local DIM = "on_surface/0.38"
local TRACK = "on_surface/0.12"
local SMALL = 11

local SEGMENTS = 16
local POLL_EVERY = 5

local s = {
  open = false, tick = 0,
  wifi = nil, ssid = nil, nets = nil, expanded = false, scanning = false, hasNmcli = true,
  bt = nil, btDevices = nil, hasBt = true,
  dnd = nil, night = nil,
  vol = nil, muted = false, hasWpctl = true,
  brt = nil, hasBrt = true,
  battery = nil, batteryPath = nil,
  uptime = nil,
}

-- ── helpers ────────────────────────────────────────────────────────────────

local function trim(x) return noctalia.string.trim(x or "") end

-- Runs argv, calls cb(stdout) on success or cb(nil) when the tool is missing or fails.
local function run(argv, cb)
  if not noctalia.commandExists(argv[1]) then
    if cb then cb(nil, "missing") end
    return
  end
  local ok = noctalia.runAsync(argv, function(r)
    if cb then
      if r.exitCode == 0 then cb(r.stdout) else cb(nil, "failed") end
    end
  end)
  if not ok and cb then cb(nil, "failed") end
end

local function fire(argv, after)
  run(argv, function() if after then after() end end)
end

local function label(text, color, extra)
  local props = { text = text, color = color or TXT }
  if extra then for k, v in pairs(extra) do props[k] = v end end
  return ui.label(props)
end

local function bracket(on)
  if on == true then return label("[■]", ACC) end
  if on == false then return label("[ ]", DIM) end
  return label("[-]", DIM)
end

local function bars(signal)
  local n = tonumber(signal) or 0
  local out = {}
  for i, ch in ipairs({ "▂", "▄", "▆", "█" }) do
    out[i] = (n >= ({ 15, 40, 65, 85 })[i]) and ch or "▁"
  end
  return table.concat(out)
end

local function pad2(n) return string.format("%02d", n) end

-- ── state readers ──────────────────────────────────────────────────────────

local render -- forward

local function readNet(rescan)
  run({ "nmcli", "radio", "wifi" }, function(out, why)
    s.hasNmcli = why ~= "missing"
    if out then s.wifi = trim(out) == "enabled" else s.wifi = nil end
    render()
  end)
  if rescan then s.scanning = true end
  run({ "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", rescan and "auto" or "no" },
    function(out)
      s.scanning = false
      if not out then s.nets, s.ssid = nil, nil; render(); return end
      local nets, seen = {}, {}
      for line in string.gmatch(out, "[^\n]+") do
        local inUse = string.sub(line, 1, 1) == "*"
        local rest = string.sub(line, 3)
        local ssid, sig = string.match(rest, "^(.*):(%d+)$")
        if ssid then
          ssid = string.gsub(ssid, "\\:", ":")
          if ssid ~= "" and not seen[ssid] then
            seen[ssid] = true
            table.insert(nets, { ssid = ssid, signal = tonumber(sig), active = inUse })
          end
        end
      end
      table.sort(nets, function(a, b)
        if a.active ~= b.active then return a.active end
        return a.signal > b.signal
      end)
      s.nets = nets
      s.ssid = nil
      for _, n in ipairs(nets) do if n.active then s.ssid = n.ssid end end
      render()
    end)
end

local function readBt()
  run({ "bluetoothctl", "show" }, function(out, why)
    s.hasBt = why ~= "missing"
    if out then s.bt = string.find(out, "Powered: yes", 1, true) ~= nil else s.bt = nil end
    render()
  end)
  run({ "bluetoothctl", "devices", "Connected" }, function(out)
    if not out then s.btDevices = nil; render(); return end
    local n = 0
    for _ in string.gmatch(out, "Device ") do n += 1 end
    s.btDevices = n
    render()
  end)
end

local function readDnd()
  run({ "noctalia", "msg", "notification-dnd-status" }, function(out)
    if out then s.dnd = string.find(string.lower(out), "on", 1, true) ~= nil else s.dnd = nil end
    render()
  end)
end

-- No IPC or config value reflects the live night-light state at plugin API 46.
local function readNight()
  s.night = nil
end

local function readVol()
  run({ "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(out, why)
    s.hasWpctl = why ~= "missing"
    if not out then s.vol = nil; render(); return end
    local v = tonumber(string.match(out, "Volume:%s*([%d%.]+)"))
    s.vol = v and math.floor(v * 100 + 0.5) or nil
    s.muted = string.find(out, "MUTED", 1, true) ~= nil
    render()
  end)
end

local function readBrt()
  run({ "brightnessctl", "-m" }, function(out, why)
    s.hasBrt = why ~= "missing"
    s.brt = out and tonumber(string.match(out, ",(%d+)%%,")) or nil
    render()
  end)
end

local function findBattery()
  local entries = noctalia.listDir("/sys/class/power_supply")
  s.batteryPath = nil
  if entries then
    for _, name in ipairs(entries) do
      if string.sub(name, 1, 3) == "BAT" then
        s.batteryPath = "/sys/class/power_supply/" .. name .. "/capacity"
        break
      end
    end
  end
end

local function readClockAndBattery()
  noctalia.readFileAsync("/proc/uptime", function(contents)
    local secs = contents and tonumber(string.match(contents, "^([%d%.]+)")) or nil
    s.uptime = secs and math.floor(secs) or nil
    render()
  end)
  if s.batteryPath then
    noctalia.readFileAsync(s.batteryPath, function(contents)
      s.battery = contents and tonumber(trim(contents)) or nil
    end)
  end
end

local function refreshAll()
  readNet(false); readBt(); readDnd(); readNight(); readVol(); readBrt()
end

-- ── actions ────────────────────────────────────────────────────────────────

local function toggleWifi()
  if s.wifi == nil then return end
  fire({ "nmcli", "radio", "wifi", s.wifi and "off" or "on" }, function() readNet(false) end)
end

local function toggleExpand()
  s.expanded = not s.expanded
  if s.expanded then readNet(true) end
  render()
end

local function connect(net)
  if net.active then return end
  run({ "nmcli", "dev", "wifi", "connect", net.ssid }, function(out)
    if out then readNet(false); return end
    -- Unknown or secured network: hand off to Noctalia's own network tab.
    panel.close()
    fire({ "noctalia", "msg", "panel-open", "control-center", "network" })
  end)
end

local function toggleBt()
  if s.bt == nil then return end
  fire({ "bluetoothctl", "power", s.bt and "off" or "on" }, readBt)
end

local function toggleDnd()
  fire({ "noctalia", "msg", "notification-dnd-toggle" }, readDnd)
end

local function toggleNight()
  fire({ "noctalia", "msg", "nightlight-force-toggle" })
end

local function setVol(pct)
  fire({ "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", string.format("%.2f", pct / 100) }, readVol)
end

local function toggleMute()
  fire({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" }, readVol)
end

local function setBrt(pct)
  fire({ "brightnessctl", "set", tostring(pct) .. "%" }, readBrt)
end

local function openSession()
  panel.close()
  fire({ "noctalia", "msg", "panel-open", "session" })
end

-- ── view ───────────────────────────────────────────────────────────────────

local function header()
  return ui.column({ gap = 6 }, {
    ui.row({ align = "center" }, {
      label("SYS // CONTROL", ACC, { flexGrow = 1 }),
      label("NP-01", DIM, { fontSize = SMALL }),
    }),
    ui.box({ height = 1, fill = "primary/0.7" }),
  })
end

local function toggleRow(key, name, on, value, valueColor, onToggle, onValue, trailingGlyph)
  local right = {}
  if value then table.insert(right, label(value, valueColor or MUTED)) end
  if trailingGlyph then table.insert(right, ui.glyph({ name = trailingGlyph, size = 14, color = DIM })) end
  return ui.row({ key = key, align = "center", gap = 8 }, {
    ui.row({ align = "center", gap = 8, flexGrow = 1, onClick = onToggle }, { bracket(on), label(name) }),
    ui.row({ align = "center", gap = 6, onClick = onValue or onToggle }, right),
  })
end

local function netList()
  local rows = {}
  if s.scanning and not s.nets then
    table.insert(rows, label("SCANNING ▁▂▄", DIM))
  elseif not s.nets or #s.nets == 0 then
    table.insert(rows, label("NO SIGNAL", DIM))
  else
    for i, net in ipairs(s.nets) do
      if i > 6 then break end
      local color = net.active and ACC or MUTED
      table.insert(rows, ui.row({ key = "net-" .. net.ssid, align = "center", gap = 6, onClick = function() connect(net) end }, {
        label(net.active and "»" or " ", color),
        label(net.ssid, color, { flexGrow = 1, maxLines = 1 }),
        label(bars(net.signal), color),
      }))
    end
  end
  return ui.row({ gap = 0 }, {
    ui.box({ width = 22 }),
    ui.column({ gap = 4, flexGrow = 1, paddingV = 2 }, rows),
  })
end

local function meter(key, name, value, onSet, onLabel, note)
  local shown, color = "--", DIM
  if note then shown, color = note, DIM
  elseif value then shown, color = tostring(value), ACC end
  local lit = value and math.floor(value / 100 * SEGMENTS + 0.5) or 0
  local segs = {}
  for i = 1, SEGMENTS do
    local pct = math.floor(i / SEGMENTS * 100 + 0.5)
    segs[i] = ui.box({
      key = key .. i, height = 10, flexGrow = 1, radius = 1,
      fill = (value and i <= lit) and ((note == "MUTE") and "primary/0.35" or ACC) or TRACK,
      onClick = value and function() onSet(pct) end or nil,
    })
  end
  return ui.column({ gap = 4 }, {
    ui.row({ align = "center", onClick = onLabel }, { label(name, MUTED, { flexGrow = 1 }), label(shown, color) }),
    ui.row({ gap = 2 }, segs),
  })
end

local function stat(name, value, alert)
  return ui.row({ gap = 6, align = "center" }, {
    label(name, MUTED),
    label(value or "--", value and (alert and ERR or ACC) or DIM),
  })
end

local function telemetry()
  local st = noctalia.systemStats()
  local cpu, gpu, third, thirdName, alert = nil, nil, nil, "RAM", false
  if st then
    if st.cpu and st.cpu.usagePercent then cpu = string.format("%d%%", math.floor(st.cpu.usagePercent + 0.5)) end
    if st.gpu and st.gpu.tempC then gpu = string.format("%d°", math.floor(st.gpu.tempC + 0.5)) end
    if st.ram and st.ram.usagePercent then third = string.format("%d%%", math.floor(st.ram.usagePercent + 0.5)) end
  end
  if s.batteryPath then
    thirdName = "BAT"
    third = s.battery and string.format("%d%%", s.battery) or nil
    alert = s.battery ~= nil and s.battery <= 10
  end
  return ui.row({ justify = "space_between", align = "center" }, {
    stat("CPU", cpu), stat("GPU", gpu), stat(thirdName, third, alert),
  })
end

local function dot(on)
  if on == true then return ui.box({ width = 6, height = 6, radius = 1, fill = ACC }) end
  if on == false then return ui.box({ width = 6, height = 6, radius = 1, border = DIM, borderWidth = 1 }) end
  return ui.box({ width = 6, height = 6, radius = 1, fill = TRACK })
end

local function footer()
  local up = "--:--:--"
  if s.uptime then
    up = pad2(s.uptime // 3600) .. ":" .. pad2((s.uptime // 60) % 60) .. ":" .. pad2(s.uptime % 60)
  end
  local yday = os.date("*t").yday
  return ui.row({ align = "center", gap = 5 }, {
    dot(s.wifi), dot(s.bt), dot(s.dnd), dot(s.night),
    label("·· ··", DIM, { fontSize = SMALL, flexGrow = 1 }),
    label("UPT " .. up, DIM, { fontSize = SMALL, flexGrow = 1 }),
    label("T+" .. string.format("%03d", yday), DIM, { fontSize = SMALL }),
  })
end

render = function()
  if not s.open then return end

  local netValue, netColor = s.ssid, MUTED
  if not s.hasNmcli then netValue, netColor = "NO SIGNAL", DIM
  elseif s.wifi == false then netValue, netColor = "OFF", DIM
  elseif s.wifi and not s.ssid then netValue, netColor = "--", DIM end

  local btValue, btColor = nil, MUTED
  if not s.hasBt then btValue, btColor = "NO SIGNAL", DIM
  elseif s.bt == false then btValue, btColor = "OFF", DIM
  elseif s.btDevices then btValue = string.format("%d DEV", s.btDevices)
  else btValue, btColor = "--", DIM end

  local body = {
    header(),
    toggleRow("net", "NET", s.wifi, netValue, netColor, toggleWifi, toggleExpand, s.expanded and "chevron-down" or "chevron-right"),
  }
  if s.expanded then table.insert(body, netList()) end
  table.insert(body, toggleRow("bt", "BT LINK", s.bt, btValue, btColor, toggleBt))
  table.insert(body, toggleRow("dnd", "QUIET", s.dnd, nil, nil, toggleDnd))
  table.insert(body, toggleRow("night", "NIGHT", s.night, nil, nil, toggleNight))

  local volNote = nil
  if not s.hasWpctl then volNote = "NO SIGNAL" elseif s.muted then volNote = "MUTE" end
  table.insert(body, meter("vol", "VOL", s.vol, setVol, toggleMute, volNote))
  table.insert(body, meter("brt", "BRT", s.brt, setBrt, nil, (not s.hasBrt or s.brt == nil) and "NO SIGNAL" or nil))
  table.insert(body, telemetry())
  table.insert(body, ui.box({ height = 1, fill = TRACK }))
  table.insert(body, ui.row({ key = "pwr", align = "center", gap = 8, onClick = openSession }, {
    ui.glyph({ name = "power", size = 14, color = MUTED }),
    label("PWR", TXT, { flexGrow = 1 }),
    label("SESSION", MUTED),
    ui.glyph({ name = "chevron-right", size = 14, color = DIM }),
  }))
  table.insert(body, footer())

  panel.render(ui.column({ gap = 10 }, body))
end

-- ── lifecycle ──────────────────────────────────────────────────────────────

function onOpen()
  s.open, s.tick, s.expanded = true, 0, false
  noctalia.setGpuMonitoring(true)
  findBattery()
  readClockAndBattery()
  refreshAll()
  panel.setWantsSecondTicks(true)
  render()
end

function onClose()
  s.open = false
  noctalia.setGpuMonitoring(false)
  panel.setWantsSecondTicks(false)
end

function update()
  if not s.open then return end
  s.tick += 1
  readClockAndBattery()
  if s.tick % POLL_EVERY == 0 then refreshAll() end
end

-- noctalia msg plugin kunu/nasa-sys:panel all <event>
function onIpc(event)
  if event == "expand-net" and s.open and not s.expanded then toggleExpand()
  elseif event == "collapse-net" and s.open and s.expanded then toggleExpand()
  elseif event == "refresh" and s.open then refreshAll() end
end

function onConfigChanged()
  render()
end
