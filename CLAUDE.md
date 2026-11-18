# test-noc: rules for Claude

Noctalia v5 NASA-punk rice test harness. See `harness/README.md` and
`theme/README.md`. Kunu often works from his phone via Remote Control.

## Iterating on the theme
- One small change per iteration, in `theme/config.toml`.
- Test in the harness first:
  `cd harness && ./shot.sh ../theme out/<step> steps/panels.txt`
- Copy the screenshots worth reviewing into `screenshots/<step>/`, commit,
  push, and tell Kunu the paths (he reviews them on GitHub mobile).

## Applying to the live PC
- Only when Kunu explicitly says "apply".
- Only with `~/.local/bin/rice-apply.sh apply` (backs up first).
  Undo with `rice-apply.sh rollback`.
- After applying, run `~/.local/bin/pc-shot screenshots/<step>/live.png`,
  commit and push it. If the screen is locked, say so.

## Never
- Run `sudo` or `pacman`/`paru`. If root is needed, stop, give Kunu the
  exact command and why, and wait.
- Edit the Noctalia Greeter, anything in /etc, ~/.config/hypr, systemd
  units, Tailscale/SSH, or `tools/remote/` and the installed copies.
- Reboot, log out, suspend, or touch networking.
