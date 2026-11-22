if status is-interactive
    # No "Welcome to fish" banner
    set -g fish_greeting

    # Prompt: Starship (end-4 style). Config: ~/.config/starship.toml
    if type -q starship
        starship init fish | source
    end

    # ls with folder/file icons (needs a Nerd Font: kitty uses JetBrainsMono Nerd Font)
    if type -q eza
        alias ls 'eza --icons --group-directories-first'
        alias ll 'eza --icons --group-directories-first -l --git'
        alias la 'eza --icons --group-directories-first -la --git'
        alias lt 'eza --icons --tree --level=2'
    end

    # Clear screen and scrollback (end-4)
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
end
