-- NASA-punk: "soft" Noctalia panels and foot, with more diffusion than Noctalia's defaults.
-- Copy to ~/.config/hypr/custom/noctalia-blur.lua and load it from your Hyprland Lua config.
--
-- Noctalia draws the panels with some alpha (shell.panel.transparency_mode = "soft",
-- bar background_opacity = 0.85, foot alpha = 0.90). Hyprland, not Noctalia, blurs what
-- shows through. Starting point: docs.noctalia.dev → Compositor settings → Hyprland
-- (size 3, passes 2). Diffusion here = larger kernel + one more pass + a little grain.

hl.config({
  decoration = {
    blur = {
      enabled = true,
      xray = true,        -- blur only the wallpaper, not windows behind: same look everywhere
      size = 8,           -- docs: 3. Kernel radius; the main "diffusion" knob
      passes = 3,         -- docs: 2. Smoother falloff; each pass costs GPU time
      noise = 0.0,        -- rev 2.4: clean blur, no grain (A/B round 6)
      contrast = 0.9,     -- slightly flatter so labels on top stay legible
      brightness = 0.85,  -- darker frost for the graphite surfaces
      vibrancy = 0.1696,
    },
  },
})

hl.layer_rule({
  name = "noctalia",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,         -- Noctalia animates its own panels
  ignore_alpha = 0.5,     -- don't blur fully transparent padding/shadow around panels
  blur = true,
  blur_popups = true,
})
