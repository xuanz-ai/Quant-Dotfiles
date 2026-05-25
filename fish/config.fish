if status is-interactive
    fastfetch
end

# Starship
starship init fish | source

# Alias edgy dikit
alias ls="eza --icons"
alias ll="eza -lah --icons --git"
alias cat="bat"
alias grep="rg"

# Better cd
zoxide init fish | source

# Colors
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERM xterm-256color

# Anime hacker bullshit energy
set fish_greeting ""

# Cursor
set fish_cursor_default block
set fish_cursor_insert line

# PATH tambahan
fish_add_path ~/.local/bin