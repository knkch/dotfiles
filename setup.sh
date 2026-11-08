#!/usr/bin/env bash
# 新しい Arch Linux にこの環境を入れる (README の「使い方」を参照)
#   ./setup.sh            すべての手順を順に実行
#   ./setup.sh <手順>...   指定した手順だけ (例: ./setup.sh packages services)
# 何度実行しても同じ結果になる (入っているものは飛ばす)
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STEPS=(pacman packages aur blackarch system services user dotfiles)

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m警告: %s\033[0m\n' "$*"; }
ask()  { local a; read -rp "$1 [y/N] " a; [[ $a == [yY] ]]; }
# packages/ の一覧を配列に読む (空行と # の行は飛ばす)
list() {
    local -n _out=$1
    shift
    mapfile -t _out < <(cd "$REPO/packages" && grep -vhE '^\s*(#|$)' "$@")
}

# pacman の見た目と速さ (色・並列ダウンロード)
step_pacman() {
    info "pacman の設定"
    sudo sed -i -e 's/^#Color$/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
    grep -q '^ILoveCandy' /etc/pacman.conf || sudo sed -i '/^Color$/a ILoveCandy' /etc/pacman.conf
    sudo install -m644 "$REPO/system/etc/pacman.d/mirrorlist" /etc/pacman.d/mirrorlist
}

step_packages() {
    info "公式リポジトリのパッケージ"
    local files=(pacman.txt) pkgs
    grep -q GenuineIntel /proc/cpuinfo && files+=(intel.txt)
    list pkgs "${files[@]}"
    sudo pacman -Syu --needed "${pkgs[@]}"
}

step_aur() {
    info "AUR のパッケージ (yay)"
    if ! command -v yay >/dev/null; then
        local tmp; tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    local pkgs; list pkgs aur.txt
    yay -S --needed "${pkgs[@]}"
}

# BlackArch はセキュリティ検証用のツール集。使わないなら飛ばしてよい
step_blackarch() {
    info "BlackArch (任意)"
    ask "BlackArch リポジトリとツールを入れますか?" || return 0
    if ! grep -q '^\[blackarch\]' /etc/pacman.conf; then
        local tmp; tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/strap.sh" https://blackarch.org/strap.sh
        echo "strap.sh の SHA1: $(sha1sum "$tmp/strap.sh" | cut -d' ' -f1)"
        echo "https://blackarch.org/downloads.html#install-repo に載っている値と同じか確認してください"
        ask "一致しましたか?" || { rm -rf "$tmp"; return 0; }
        sudo bash "$tmp/strap.sh"
        rm -rf "$tmp"
    fi
    sudo install -m644 "$REPO/system/etc/pacman.d/blackarch-mirrorlist" /etc/pacman.d/blackarch-mirrorlist
    local pkgs; list pkgs blackarch.txt
    sudo pacman -Syu --needed "${pkgs[@]}"
}

# /etc に置く設定 (ログイン画面・時刻・省電力など)
step_system() {
    info "システムの設定ファイル"
    local f
    for f in greetd/config.toml pam.d/greetd systemd/timesyncd.conf.d/nict.conf udev/rules.d/50-pci-runtime-pm.rules; do
        sudo install -D -m644 "$REPO/system/etc/$f" "/etc/$f"
    done
    # systemd-boot を使っているときだけ、systemd の更新時にブートローダーも更新する
    if bootctl is-installed >/dev/null 2>&1; then
        sudo install -D -m644 "$REPO/system/etc/pacman.d/hooks/systemd-boot.hook" /etc/pacman.d/hooks/systemd-boot.hook
    fi
}

step_services() {
    info "サービスの有効化"
    sudo systemctl enable NetworkManager bluetooth greetd power-profiles-daemon systemd-timesyncd ufw sshd \
        fstrim.timer paccache.timer pkgfile-update.timer
    grep -q GenuineIntel /proc/cpuinfo && sudo systemctl enable thermald
    systemctl --user enable mpd.socket
    # ファイアウォール: 外からは SSH だけ受け付ける
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22
    sudo ufw --force enable
}

step_user() {
    info "ユーザーの設定"
    getent group wireshark >/dev/null && sudo usermod -aG wireshark "$USER"
    # zsh をログインシェルに
    [[ $(getent passwd "$USER" | cut -d: -f7) == /usr/bin/zsh ]] || chsh -s /usr/bin/zsh
    # Tab 補完を fzf で選ぶプラグイン (パッケージが無いので git で入れる)
    local fzf_tab=~/.local/share/zsh/plugins/fzf-tab
    [[ -d $fzf_tab ]] || git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$fzf_tab"
    # Rust: rustup で stable を入れ、rust-analyzer を PATH に出す
    rustup default stable
    rustup component add rust-analyzer
    mkdir -p ~/.local/bin
    ln -sf /usr/bin/rustup ~/.local/bin/rust-analyzer
    xdg-user-dirs-update
    mkdir -p ~/Pictures/Screenshots
}

step_dotfiles() {
    info "dotfiles を展開 (chezmoi)"
    chezmoi apply -v
    ~/.local/bin/make-lockscreen
}

main() {
    [[ $EUID -ne 0 ]] || { echo "root ではなく普通のユーザーで実行してください (必要なところで sudo を使います)"; exit 1; }
    local steps=("$@")
    (( ${#steps[@]} )) || steps=("${STEPS[@]}")
    local s
    for s in "${steps[@]}"; do
        declare -F "step_$s" >/dev/null || { echo "不明な手順: $s (使えるもの: ${STEPS[*]})"; exit 1; }
        "step_$s"
    done
    info "完了。再起動するとログイン画面 (tuigreet) から Awesome が起動します"
}

main "$@"
