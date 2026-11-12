<a href="https://git.io/typing-svg"><img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=25&pause=1000&color=F7F7F7&center=false&width=435&lines=Fuzzy-CD+%F0%9F%93%82" alt="Typing SVG" /></a>

**A** Bash/Zsh shell function that fuzzy-searches for a folder with `fzf` and jumps straight into it. Ships as a single `main.sh` file you can source by hand or load automatically from `~/.bashrc` / `~/.zshrc` — no install step, no dependencies beyond `fzf`.

## Features:
- **Fuzzy folder jump:** Type a few letters, press Enter, and your shell is already inside the folder (`fcd`).
- **File mode:** Search for a file instead and `cd` into the folder that contains it (`fcd -f`).
- **Recent folders:** Every jump is saved, so `fcd -r` brings back places you visited before, newest first.
- **Search controls:** Hidden folders (`-a`), depth limit (`-d N`), pre-filled query (`-q`), extra excludes (`-x`), auto-jump on a single match (`-1`).
- **Quick starts:** Search from home (`-H`) or from `/` (`-R`), or pass any start directory.
- **Print mode:** `-p` prints the chosen path instead of changing directory, for use in pipes and `$(...)`.
- **Live preview:** Folder contents via `ls`, or file contents via `bat` / `head` in file mode.
- **Built-in help:** `fcd -h` or `fcd --help` shows full usage and examples.
- **Smart backends:** Uses `fd` / `fdfind` when installed, falls back to `find` otherwise.
- **Safe input handling:** Unknown options, missing arguments, bad depth values and missing `fzf` give clear errors.
- **Shortcuts:** `Ctrl+F` keybinding plus the `fcdh`, `fcdr`, `fcdf` aliases.

## Technologies:
- **Language:** Bash (also loads in Zsh)
- **Picker:** [fzf](https://github.com/junegunn/fzf)
- **Optional:** [fd](https://github.com/sharkdp/fd) for faster searching, [bat](https://github.com/sharkdp/bat) for file previews
- **Frontend:** none, pure shell

## Before Getting Started:
- [fzf](https://github.com/junegunn/fzf#installation) installed:
  ```bash
  sudo apt install fzf        # Debian / Ubuntu
  brew install fzf            # macOS
  ```
- Optional, for speed: `sudo apt install fd-find` (installs as `fdfind`) or `brew install fd`.

## Getting Started:
1. **Clone the repository:**
   ```bash
   git clone https://github.com/1Xer0/fuzzy-cd.git
   cd fuzzy-cd
   ```

2. **Pick how you want to use `main.sh`:**

   > `main.sh` must be **sourced**, not executed. A script running in a child process cannot change the directory of your current shell.

   **Option A: try it in the current terminal only**
   ```bash
   source ./main.sh
   fcd
   ```

   **Option B: integrate with Bash (`~/.bashrc`)**
   ```bash
   cp main.sh ~/main.sh
   echo 'source ~/main.sh' >> ~/.bashrc
   source ~/.bashrc
   ```

   **Option C: integrate with Zsh (`~/.zshrc`)**
   ```zsh
   cp main.sh ~/main.sh
   echo 'source ~/main.sh' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Run it:**
   ```bash
   fcd            # fuzzy-search folders below the current directory
   fcd -h         # show the help message
   ```

4. **Example session:**
   ```
   $ pwd
   /home/ali
   $ fcd -d 3 -q disc
   fcd> disc
     projects/school/discrete-structures
     projects/school/discrete-structures/notes
   $ pwd
   /home/ali/projects/school/discrete-structures
   ```

## Project Structure:

```
fuzzy-cd/
├── README.md
└── main.sh
```

## Options:

| Flag | Long form | Description |
|------|-----------|-------------|
| `-h` | `--help` | Show the help message and exit |
| `-a` | `--hidden` | Include hidden folders |
| `-d N` | `--depth N` | Limit search depth to `N` levels |
| `-f` | `--files` | Search files, jump to the chosen file's folder |
| `-q TEXT` | `--query TEXT` | Start fzf with `TEXT` already typed |
| `-x NAME` | `--exclude NAME` | Exclude folders named `NAME` (repeatable) |
| `-r` | `--recent` | Pick from previously visited folders |
| `-p` | `--print` | Print the path instead of changing directory |
| `-n` | `--no-preview` | Disable the preview pane |
| `-1` | `--select-1` | Jump immediately if there is only one match |
| `-H` | `--home` | Search from `~` |
| `-R` | `--root` | Search from `/` (can be slow) |

Short flags cannot be combined: use `-a -d 2`, not `-ad 2`.

## Implementation:
### Argument parsing (`fcd` in `main.sh`)

1. **Loop** over `$@` with a `case` statement, one branch per flag.
2. **Flags with values** (`-d`, `-q`, `-x`) check that an argument follows, then `shift` past it.
3. **Unknown options** print an error and point to `fcd --help`.
4. **Validation** checks that `fzf` exists, the start path is a directory, and depth is a number.

### Candidate search

1. **`fd` / `fdfind`** is used when available, with `--type d` (or `f`), `--max-depth`, and one `--exclude` per excluded name.
2. **`find` fallback** builds an equivalent expression: excluded names are pruned, hidden entries are pruned unless `-a` is set, then matching types are printed.
3. **Recent mode** skips searching and reads `~/.fcd_history` instead, reversed with `tac` (or `tail -r` on macOS) and de-duplicated with `awk`.
4. **Default excludes:** `.git`, `node_modules`, `.cache`, `__pycache__`, `.venv`.

### Picker and jump

1. **`fzf`** gets a reversed 40% height layout, the `fcd>` prompt, and a preview command chosen by mode.
2. **Selection** is turned into a directory: in file mode, `dirname` of the pick.
3. **Jump:** `cd --` into the result, then append `$PWD` to the history file.
4. **Print mode** resolves the absolute path with `cd && pwd` and prints it without moving.

### Shell integration

- **Source guard:** executing `main.sh` directly prints the exact `source` line to use instead.
- **Keybinding:** `Ctrl+F` runs `fcd`. Bash uses `bind -x`; Zsh uses a small `zle` widget with `bindkey`. Only set in interactive shells.
- **Aliases:** `fcdh` (`fcd -H`), `fcdr` (`fcd -r`), `fcdf` (`fcd -f`).

## Configuration:

| Variable | Default | Purpose |
|----------|---------|---------|
| `FCD_HISTORY` | `~/.fcd_history` | Where visited folders are stored |

To change it, export the variable before sourcing `main.sh`:
```bash
export FCD_HISTORY="$HOME/.config/fcd_history"
source ~/main.sh
```

## Usage:

1. Source `main.sh` (or add it to your rc file once).
2. Run `fcd`, type part of a folder name, press **Enter**. **Esc** cancels without moving.
3. Narrow or widen the search with flags, for example:
   ```bash
   fcd -H -d 3            # search home, max 3 levels deep
   fcd -a -q config       # include hidden folders, start with "config"
   fcd -f                 # find a file, jump to its folder
   fcd -r                 # jump back to a recent folder
   fcd -x build -x dist   # also skip build and dist folders
   ls "$(fcd -p)"         # use the pick in another command
   ```
4. Press **Ctrl+F** anywhere on the command line as a shortcut for `fcd`.

## Troubleshooting:
- **`fcd: command not found`:** `main.sh` is not sourced in this shell. Run `source ~/main.sh` or check your rc file.
- **`main.sh must be sourced, not executed`:** use `source main.sh`, not `./main.sh`.
- **`fcd: fzf is not installed`:** install `fzf` (see Before Getting Started).
- **Nothing found:** add `-a` for hidden folders, or check that the folder is not in the exclude list.
- **Slow on big trees:** install `fd`, limit depth with `-d`, or avoid `-R`.

### Author:
* **Ali Abdullah** `@aliyabdullah` `👑`