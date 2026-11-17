--!nonstrict
-- Bar entry for frosted telemetry quick settings: a small "SYS" label that toggles the panel.

barWidget.setGlyph("adjustments-horizontal")
barWidget.setText("SYS")
barWidget.setTooltip("Quick settings")

function onClick()
  noctalia.togglePanel("kunu/telemetry:quick")
end
