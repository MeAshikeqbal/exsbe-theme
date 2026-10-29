# Exsbe palette for CLI tools, sourced at the end of ~/.zshrc.

# fzf: graphite, rounded, results top-down; Ctrl+T previews files with bat
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --layout=reverse --height=50% --border=rounded --info=inline-right \
  --pointer='▌' --marker='+' --separator='─' --scrollbar='│' \
  --color=fg:#c8c8cc,fg+:#e6e6e8,bg:-1,bg+:#2e2e32,gutter:-1,hl:#7fa8d6,hl+:#9fc0e6 \
  --color=info:#a8a8b0,prompt:#8fa4c0,pointer:#8fa4c0,marker:#8fc79a,spinner:#b494d6 \
  --color=header:#a8a8b0,border:#3a3a3f,separator:#3a3a3f,scrollbar:#5a5a62,query:#e6e6e8"
command -v bat >/dev/null && export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"

# bat and delta use the terminal's own (Exsbe) 16 colours
export BAT_THEME=ansi

# eza: muted metadata, accent directories
export EZA_COLORS="di=38;2;127;168;214:ex=38;2;143;199;154:ln=38;2;127;200;200:ur=38;2;168;168;176:uw=38;2;168;168;176:ux=38;2;168;168;176:gr=38;2;90;90;98:gw=38;2;90;90;98:gx=38;2;90;90;98:tr=38;2;90;90;98:tw=38;2;90;90;98:tx=38;2;90;90;98:sn=38;2;200;200;204:sb=38;2;90;90;98:da=38;2;90;90;98:uu=38;2;168;168;176:gu=38;2;90;90;98:hd=4;38;2;168;168;176:ga=38;2;143;199;154:gm=38;2;224;196;122:gd=38;2;224;122;122"

# zsh-autosuggestions / zsh-syntax-highlighting
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5a5a62'
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#8fc79a'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#8fc79a'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#8fc79a'
ZSH_HIGHLIGHT_STYLES[function]='fg=#8fc79a'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#8fc79a,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#b494d6'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#e07a7a'
ZSH_HIGHLIGHT_STYLES[path]='fg=#e6e6e8,underline'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#e0c47a'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#e0c47a'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#e0c47a'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#7fa8d6'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#7fa8d6'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#7fc8c8'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#a8a8b0'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#a8a8b0'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#5a5a62'

# system info with the Exsbe logo in each new kitty window (not in containers or editors)
if [[ -o interactive && $TERM == xterm-kitty && -z $CONTAINER_ID && -z $EXSBE_GREETED ]]; then
  export EXSBE_GREETED=1
  command -v fastfetch >/dev/null && fastfetch
fi
