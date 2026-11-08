# dotfiles

My Arch Linux + Awesome WM desktop.
Home configs are managed with [chezmoi](https://www.chezmoi.io/); `setup.sh` installs packages, system settings and services.

Everything uses the Catppuccin Mocha palette (bar, terminal, editor, launcher, lock screen).

**Installing on a new machine: see [INSTALL.md](INSTALL.md).**

## Stack

| Area | Tools |
|---|---|
| Login | greetd + tuigreet → `startx` → Awesome |
| Window manager | Awesome 4.3 (frosted-glass tile bar, dock, app menu) |
| Compositor | picom (blur only behind the bar and Ghostty) |
| Terminal | Ghostty + tmux + zsh (starship / fzf / zoxide / atuin) |
| Editor | Neovim 0.12 (lazy.nvim / LSP / completion / debugger / Markdown) |
| Launcher | rofi |
| Japanese input | fcitx5 + Mozc |
| Screen lock | xss-lock + i3lock-color |
| Other | Thunar / CopyQ / flameshot / gammastep / udiskie / MPD + rmpc |

## Layout

```
.
├── dot_config/        -> ~/.config
├── dot_local/         -> ~/.local (scripts in ~/.local/bin)
├── dot_*              -> ~/.zshrc, ~/.xinitrc, ...
├── packages/          package lists (not deployed to $HOME)
├── system/etc/        files for /etc (installed by setup.sh)
├── setup.sh
├── README.md
├── INSTALL.md
└── THIRD_PARTY_NOTICES.md
```

Files ending in `.tmpl` are chezmoi templates. `{{ .chezmoi.homeDir }}` becomes the home directory of each machine, and the Git name/email come from the answers to `chezmoi init`.

### Awesome (`dot_config/awesome/`)

`rc.lua` only defines the load order; everything else lives in `modules/`.

| File | Purpose |
|---|---|
| `modules/config.lua` | Frequently changed settings (apps, modifier key, tags, layouts) |
| `modules/theme.lua` | Colors, fonts and shared widgets (tile, popup, slider) |
| `modules/bar.lua` | Top bar (the window is clipped to the tiles so only they get blurred) |
| `modules/keys.lua` | Key bindings. Press Super+s for the list |
| `modules/rules.lua`, `signals.lua` | Window rules, titlebars, focus |
| `modules/widgets/` | Volume, brightness, battery, VPN, clock, MPD, wallpaper, app menu, dock |
| `dock-apps` | Apps pinned to the dock (rewritten when you edit the dock with right-click or drag) |

### Neovim (`dot_config/nvim/`)

Core settings are in `lua/config/`, plugins grouped by purpose in `lua/plugins/` (`ui`, `coding`, `lsp`, `lang`, `markdown`, `tools`, `snacks`). The leader key is Space; wait after pressing it and which-key lists the bindings.

## Key bindings

| Key | Action |
|---|---|
| Super+Enter | Terminal (tmux) |
| Super+a / Super+p | App menu / rofi |
| Super+e | Thunar |
| Super+v | Clipboard history |
| Super+s | Shortcut list |
| Super+Shift+Esc | Lock screen |
| Print / Shift+Print | Screenshot (region / full screen) |
| Super+Shift+n | Toggle night light |

## Day-to-day

```sh
chezmoi edit ~/.zshrc        # edit the repo copy and apply it
chezmoi re-add               # pull changes made directly in $HOME back into the repo
chezmoi diff                 # show differences between the repo and $HOME
chezmoi cd                   # cd into the repo (commit and push from here)
```

After installing or removing packages, regenerate the lists:

```sh
cd "$(chezmoi source-path)/packages"
pacman -Sl blackarch 2>/dev/null | awk '{print $2}' | sort > /tmp/ba
pacman -Qqem | sort > aur.txt
pacman -Qqen | sort | comm -12 - /tmp/ba > blackarch.txt
pacman -Qqen | sort | comm -23 - /tmp/ba | grep -vxF -f intel.txt > pacman.txt
```

## What is not in this repo

Files are added one by one (allowlist), so nothing else can slip in. These are left out on purpose:

- **Secrets**: SSH keys, keyrings, VPN configs, browser profiles, tool API keys, Metasploit DB config, GitHub Desktop login
- **History and personal data**: shell history, clipboard history, Mozc user dictionary
- **Machine-specific files**: `/etc/fstab`, SSH host keys, sudoers
- **Wallpapers**: some images can't be redistributed. Pick a folder under `~/Pictures` (falls back to `arch-wallpapers`)

Move or recreate these separately on a new machine.

Before pushing, scan for secrets:

```sh
gitleaks dir "$(chezmoi source-path)"
gitleaks git "$(chezmoi source-path)"
```

## Notes

- The greetd / PAM files in `system/etc/` unlock the GNOME keyring at login.
- The firewall (ufw) blocks all incoming connections and no SSH server runs. To log in remotely, enable it yourself: `sudo systemctl enable --now sshd && sudo ufw allow 22`.
- gammastep's location is Tokyo (`dot_config/gammastep/config.ini`). Change it for other regions.

## Third-party files

These files are not mine and keep their own licenses (details in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)):

- `dot_config/awesome/icons/` — battery and brightness icons from the GNOME [Adwaita icon theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme), recolored. CC BY-SA 3.0 (or LGPL-3.0).
- `dot_config/awesome/awesome-wm-widgets/` — the volume widget from [awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets), patched so the icon doesn't disappear when PipeWire isn't ready at startup. MIT License (included).

Everything else is my own configuration.
