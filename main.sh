#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# main.sh - fcd: fuzzy-find a folder with fzf and cd into it
#
# This file must be SOURCED (not executed), because a script running in a
# child process cannot change the directory of your current shell.
#
# Install:
#   1. Save as ~/main.sh   (or anywhere you like)
#   2. Add to ~/.bashrc (or ~/.zshrc):   source ~/main.sh
#   3. Reload:                           source ~/.bashrc   (or ~/.zshrc)
#
# Works in: bash and zsh
# Requires: fzf   (optional: fd/fdfind, bat)
# ---------------------------------------------------------------------------

# Warn if executed instead of sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "main.sh must be sourced, not executed." >&2
    echo "Add this line to ~/.bashrc:  source \"$(cd "$(dirname "$0")" && pwd)/$(basename "$0")\"" >&2
    exit 1
fi

fcd() {
    local start="." depth="" hidden=0 files=0 print_only=0 preview=1 select1=0 recent=0
    local query="" type="d"
    local -a excludes=(.git node_modules .cache __pycache__ .venv)
    local hist="${FCD_HISTORY:-$HOME/.fcd_history}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
fcd - fuzzy-find a directory with fzf and cd into it

USAGE
  fcd [OPTIONS] [START_DIR]

OPTIONS
  -h, --help           Show this help message and exit
  -a, --hidden         Include hidden folders (.config, .local, ...)
  -d, --depth N        Limit search depth to N levels
  -f, --files          Search for files instead; cd into the chosen file's folder
  -q, --query TEXT     Start fzf with TEXT already typed
  -x, --exclude NAME   Exclude folders with this name (repeatable)
  -r, --recent         Pick from folders you previously jumped to with fcd
  -p, --print          Print the chosen path instead of cd-ing into it
  -n, --no-preview     Disable the preview pane
  -1, --select-1       Auto-jump if only one match exists
  -H, --home           Search from your home folder (~)
  -R, --root           Search from / (can be slow)

NOTES
  START_DIR defaults to the current directory.
  Default excludes: .git node_modules .cache __pycache__ .venv
  Uses fd/fdfind when installed, otherwise falls back to find.
  Recent history is stored in $FCD_HISTORY (default: ~/.fcd_history).
  Options must be given separately (-a -d 2, not -ad 2).

EXAMPLES
  fcd                  Search below the current folder
  fcd ~/projects       Search inside ~/projects
  fcd -H -d 3          Search home, max 3 levels deep
  fcd -a -q config     Include hidden folders, start with "config" typed
  fcd -f               Find a file, jump to the folder containing it
  fcd -r               Jump back to a recently visited folder
  fcd -x build -x dist Also skip "build" and "dist" folders
  fcd -p | xargs ls    Print the pick instead of cd-ing
EOF
                return 0 ;;
            -a|--hidden)     hidden=1 ;;
            -f|--files)      files=1; type="f" ;;
            -r|--recent)     recent=1 ;;
            -p|--print)      print_only=1 ;;
            -n|--no-preview) preview=0 ;;
            -1|--select-1)   select1=1 ;;
            -H|--home)       start="$HOME" ;;
            -R|--root)       start="/" ;;
            -d|--depth|-q|--query|-x|--exclude)
                if [[ -z "$2" ]]; then
                    echo "fcd: option '$1' requires an argument" >&2; return 1
                fi
                case "$1" in
                    -d|--depth)   depth="$2" ;;
                    -q|--query)   query="$2" ;;
                    -x|--exclude) excludes+=("$2") ;;
                esac
                shift ;;
            --) shift; break ;;
            -*) echo "fcd: unknown option '$1'" >&2
                echo "Try 'fcd --help' for usage." >&2; return 1 ;;
            *)  start="$1" ;;
        esac
        shift
    done
    [[ -n "$1" ]] && start="$1"

    command -v fzf >/dev/null || { echo "fcd: fzf is not installed" >&2; return 1; }
    if [[ ! -d "$start" ]]; then
        echo "fcd: '$start' is not a directory" >&2; return 1
    fi
    if [[ -n "$depth" && ! "$depth" =~ ^[0-9]+$ ]]; then
        echo "fcd: depth must be a number" >&2; return 1
    fi

    # --- fzf options ---
    local -a fzfargs=(--height 40% --reverse --prompt "fcd> ")
    [[ -n "$query" ]] && fzfargs+=(--query "$query")
    (( select1 )) && fzfargs+=(--select-1 --exit-0)
    if (( preview )); then
        if (( files )); then
            if command -v bat >/dev/null; then
                fzfargs+=(--preview 'bat --color=always --line-range :50 {}')
            else
                fzfargs+=(--preview 'head -50 {}')
            fi
        else
            fzfargs+=(--preview 'ls -A --color=always {} | head -50')
        fi
    fi

    # --- build the candidate list and pick ---
    local sel
    if (( recent )); then
        if [[ ! -s "$hist" ]]; then
            echo "fcd: no history yet (jump somewhere with fcd first)" >&2; return 1
        fi
        sel=$( { tac "$hist" 2>/dev/null || tail -r "$hist"; } | awk '!seen[$0]++' | fzf "${fzfargs[@]}")
    else
        local fdcmd=""
        if command -v fd >/dev/null; then fdcmd=fd
        elif command -v fdfind >/dev/null; then fdcmd=fdfind; fi

        local -a a
        local e
        if [[ -n "$fdcmd" ]]; then
            a=(--type "$type" --no-ignore)
            (( hidden )) && a+=(--hidden)
            [[ -n "$depth" ]] && a+=(--max-depth "$depth")
            for e in "${excludes[@]}"; do a+=(--exclude "$e"); done
            sel=$("$fdcmd" "${a[@]}" . "$start" 2>/dev/null | fzf "${fzfargs[@]}")
        else
            a=("$start")
            [[ -n "$depth" ]] && a+=(-maxdepth "$depth")
            a+=(-mindepth 1 '(')
            local first=1
            for e in "${excludes[@]}"; do
                (( first )) || a+=(-o)
                a+=(-name "$e"); first=0
            done
            (( hidden )) || a+=(-o -name '.?*')
            a+=(')' -prune -o -type "$type" -print)
            sel=$(find "${a[@]}" 2>/dev/null | fzf "${fzfargs[@]}")
        fi
    fi

    [[ -z "$sel" ]] && return 1

    local dir="$sel"
    (( files )) && (( ! recent )) && dir=$(dirname "$sel")
    if [[ ! -d "$dir" ]]; then
        echo "fcd: '$dir' no longer exists" >&2; return 1
    fi

    if (( print_only )); then
        printf '%s\n' "$(cd "$dir" && pwd)"
        return 0
    fi

    cd -- "$dir" || return 1
    printf '%s\n' "$PWD" >> "$hist"
}

# Optional: press Ctrl+F to launch fcd (interactive shells only)
if [[ $- == *i* ]]; then
    if [[ -n "$BASH_VERSION" ]]; then
        bind -x '"\C-f": fcd'
    elif [[ -n "$ZSH_VERSION" ]]; then
        _fcd_widget() { BUFFER="fcd"; zle accept-line; }
        zle -N _fcd_widget
        bindkey '^F' _fcd_widget
    fi
fi

# Optional shortcuts
alias fcdh='fcd -H'      # search from home
alias fcdr='fcd -r'      # recent folders
alias fcdf='fcd -f'      # find a file, jump to its folder