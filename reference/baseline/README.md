# Baseline frames (stock Noctalia, before theme changes)

51 screenshots of stock Noctalia v5 at commit `5e4aae910b76`, 1920×1080, headless sway.
Captured 2026-11-05 with:

```bash
cd harness
RES=1920x1080 ./shot.sh ../theme out/baseline steps/baseline.txt   # 00–49
RES=1920x1080 ./shot.sh ../theme out/lock steps/lock.txt           # → 50-lock-dark.png
```

Also published as a gallery artifact: https://claude.ai/artifact/PnZgup7HXW45u9JDCtSYuW
(other artifacts can copy its `img/<name>.png` files server-side).

Not covered: control-center power / weather / screen-time tabs (hidden without battery,
location, tracking), dock and desktop widgets (nothing to show without running apps),
Hyprland blur.
