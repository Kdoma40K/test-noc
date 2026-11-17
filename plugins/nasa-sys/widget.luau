--!nonstrict
-- Bar entry for NASA-SYS: a small "SYS" label that toggles the panel.

barWidget.setGlyph("adjustments-horizontal")
barWidget.setText("SYS")
barWidget.setTooltip("NASA-SYS")

function onClick()
  noctalia.togglePanel("kunu/nasa-sys:panel")
end
