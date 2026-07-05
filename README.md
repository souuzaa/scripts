# scripts

Personal setup scripts and dotfiles for getting a fresh Linux box productive in minutes.

[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Arch](https://img.shields.io/badge/Arch-supported-1793D1?logo=archlinux&logoColor=white)](https://archlinux.org/)
[![Ubuntu / Debian](https://img.shields.io/badge/Ubuntu%2FDebian-supported-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Fedora](https://img.shields.io/badge/Fedora-supported-51A2DA?logo=fedora&logoColor=white)](https://getfedora.org/)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

## What's inside

One command turns a bare Arch, Ubuntu/Debian, or Fedora install into a ready-to-use dev machine.

| Category | Tools |
|---|---|
| Terminal | `tmux` (with a preconfigured `tmux.conf`), `btop` |
| Dev tooling | `git`, `gh` (GitHub CLI), `docker` + `docker-compose`, `bun.js`, VS Code |
| Apps | Google Chrome, Discord, draw.io |

The script auto-detects your distro, uses the right package manager (`pacman`, `apt`, `dnf`), and falls back to `yay`/AUR on Arch or Flatpak on Fedora when a package isn't in the official repos. Everything is idempotent — safe to re-run, and already-installed tools are skipped.

## Usage

```bash
git clone https://github.com/souuzaa/scripts.git
cd scripts
./install.sh
```

You'll be prompted for your `sudo` password as needed. When it's done:
- Log out and back in for the `docker` group membership to take effect.
- Restart your shell (or `source` your profile) to pick up `bun`'s `PATH` update.

## Structure

```
scripts/
├── install.sh        # Main installer — detects distro and installs everything
└── tmux/
    └── tmux.conf      # Symlinked to ~/.tmux.conf by install.sh
```

### tmux config highlights

- Status bar pinned to the top, 1-indexed windows/panes
- Vim-style pane navigation (`Ctrl+h/j/k/l`)
- `Alt+1`–`Alt+9` to jump straight to a window
- `x` kills a pane without a confirmation prompt
- `PageUp` drops straight into scroll/copy mode

## Notes

- Snap is only ever used on Ubuntu, and never for Chrome or Docker (installed from their official repos instead).
- Docker and Chrome are deliberately never installed via Snap on any distro.

## License

MIT — do whatever you'd like with it.
