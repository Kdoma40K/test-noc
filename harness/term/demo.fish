# Terminal shot: replays a short fish session (prompt + highlighted command + output),
# then leaves an interactive prompt. Run as: foot fish /term/demo.fish
set -U fish_greeting ''
cd ~
mkdir -p ~/missions/artemis ~/missions/voyager; touch ~/missions/manifest.toml ~/missions/launch.sh; chmod +x ~/missions/launch.sh

function swatches --description 'ANSI 0-15 from the palette'
    for c in black red green yellow blue magenta cyan white
        set_color -b $c; printf '    '; set_color normal; printf ' %-9s' $c
    end
    echo
    for c in black red green yellow blue magenta cyan white
        set_color -b br$c; printf '    '; set_color normal; printf ' %-9s' br$c
    end
    echo
end

function show
    fish_prompt
    echo $argv | fish_indent --ansi
    eval $argv
end

show 'fish --version'
show 'ls -la --color=always ~/missions'
show 'swatches'
show 'cat ~/missions/telemetry.log'
show 'string upper "t-minus 10"'
exec fish
