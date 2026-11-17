--!nonstrict
-- Bar entry for the frosted settings panel: a small "CFG" label that toggles it.

barWidget.setGlyph("settings")
barWidget.setText("CFG")
barWidget.setTooltip("Settings")

function onClick()
  noctalia.togglePanel("kunu/telemetry:settings")
end
