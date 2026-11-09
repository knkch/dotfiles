# Installation

How to set up this environment on a new machine.
It takes 30–60 minutes, mostly waiting for packages to download.

## Requirements

- A PC that can boot Arch Linux (UEFI; systemd-boot is assumed but not required)
- An internet connection
- This repository on GitHub (`knkch/dotfiles`)
- A phone or another PC to approve the GitHub login

## 1. Install Arch Linux

Boot the Arch ISO and run `archinstall`. Settings that work well with this repo:

| Item | Choice |
|---|---|
| Bootloader | systemd-boot |
| Profile | Minimal (the desktop is installed by `setup.sh`) |
| Audio | PipeWire |
| Network | NetworkManager |
| User | Create a normal user with sudo rights |

Reboot and log in as that user on the console.
If you need Wi-Fi: `nmcli device wifi connect "<SSID>" --ask`

## 2. Get the repository

The repository is private, so sign in to GitHub first. The easiest way on a fresh console is the GitHub CLI device login: it shows a short code that you enter on another device (phone or PC).

```sh
sudo pacman -S --needed chezmoi git github-cli
gh auth login        # GitHub.com -> HTTPS -> Login with a web browser
gh auth setup-git    # let git use the gh login
chezmoi init knkch
```

`gh auth login` prints a code like `ABCD-1234`. Open https://github.com/login/device on your phone, enter the code and approve.
`chezmoi init knkch` clones `https://github.com/knkch/dotfiles`. (If the repository is public, skip the `gh` steps.)

You are asked two questions once:

- **Git name**
- **Git email**: use your GitHub noreply address (`<id>+<user>@users.noreply.github.com`, shown in GitHub → Settings → Emails) so your real address isn't published in commits

The answers are stored only on that machine, in `~/.config/chezmoi/chezmoi.toml`, and are used to generate `~/.gitconfig`.

## 3. Run the setup script

```sh
~/.local/share/chezmoi/setup.sh
```

It asks for your sudo password when needed. It runs these steps in order:

| Step | What it does |
|---|---|
| `pacman` | Enables color and parallel downloads, installs the mirror list (Japan) |
| `yay` | Installs `base-devel`, `git` and the AUR helper yay first, so every later step can use it |
| `packages` | Official packages from `packages/pacman.txt` (plus `intel.txt` on Intel CPUs) |
| `aur` | AUR packages from `packages/aur.txt` |
| `awesome` | `awesome-git` (the latest Awesome) built against Lua 5.4 by `~/.local/bin/awesome-git-lua54`. It is added to `IgnorePkg`, so `yay -Syu` won't replace it; run `awesome-git-lua54` to update Awesome |
| `blackarch` | Optional (asks first). Adds the BlackArch repo after you compare the SHA1 of `strap.sh` with the official site, then installs `packages/blackarch.txt` |
| `system` | Copies `system/etc/` to `/etc` (login screen, time sync, power saving, zram swap + sysctl tuning, paccache keeping 2 versions). Adds the systemd-boot update hook only if systemd-boot is installed |
| `services` | Enables every service listed in `packages/services.txt` one by one (missing ones are skipped, failures are listed at the end) and sets ufw to block all incoming connections. Services start at the next boot |
| `user` | Sets zsh as the login shell, installs fzf-tab, sets up rustup and user directories |
| `dotfiles` | Runs `chezmoi apply` and generates the lock screen background |

The script is safe to run again. If a step fails, the remaining steps still run and the failed ones are listed at the end with the command to retry them. You can also run selected steps only:

```sh
~/.local/share/chezmoi/setup.sh packages services
```

## 4. Reboot

```sh
reboot
```

The tuigreet login screen appears. Log in and Awesome starts.

## 5. Finish up

- Open `nvim` once. Plugins, language servers and formatters install automatically. Wait until it finishes, then quit with `:q`.
- Copy over the things that are not in the repo (SSH keys, VPN configs, wallpapers, etc.). See "What is not in this repo" in [README.md](README.md).
- Optional:
  - Tailscale: `sudo systemctl enable --now tailscaled && sudo tailscale up`
  - Metasploit database: `msfdb init --component database`

## Using SSH instead of `gh`

```sh
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub      # add this in GitHub -> Settings -> SSH and GPG keys
chezmoi init git@github.com:knkch/dotfiles.git
```

## Troubleshooting

| Problem | Fix |
|---|---|
| A step failed halfway | Fix the cause and run the same step again: `setup.sh <step>` |
| A service didn't start | Add or fix it in `packages/services.txt`, then run `setup.sh services` |
| Firewall says it will be enabled at next boot | The kernel was updated during setup. Just reboot |
| Awesome shows an error at startup | Check with `awesome -k`. Errors also appear as a notification |
| No blur behind the bar | Check that picom is running: `pgrep picom` |
| Japanese input doesn't work | Log out and back in so fcitx5 picks up the environment from `~/.xinitrc` |
