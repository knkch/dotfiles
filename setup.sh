#!/usr/bin/env bash
# 新しい Arch Linux にこの環境を入れる (README の「使い方」を参照)
#   ./setup.sh            すべての手順を順に実行
#   ./setup.sh <手順>...   指定した手順だけ (例: ./setup.sh packages services)
# 何度実行しても同じ結果になる (入っているものは飛ばす)
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STEPS=(pacman yay packages aur awesome blackarch system services user dotfiles)

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
    # awesome-git は Lua 5.4 で自分で組むので、yay -Syu で AUR 版 (Lua 5.5) に置き換えさせない
    if ! grep -qE '^IgnorePkg\s*=.*\bawesome-git\b' /etc/pacman.conf; then
        if grep -qE '^IgnorePkg\s*=' /etc/pacman.conf; then
            sudo sed -i -E 's/^(IgnorePkg\s*=.*)$/\1 awesome-git/' /etc/pacman.conf
        else
            sudo sed -i -E 's/^#IgnorePkg\s*=.*$/IgnorePkg   = awesome-git/' /etc/pacman.conf
        fi
    fi
    sudo install -m644 "$REPO/system/etc/pacman.d/mirrorlist" /etc/pacman.d/mirrorlist
}

# yay (AUR ヘルパー) を最初に入れる。ビルドに base-devel と git が要る
step_yay() {
    info "yay (AUR ヘルパー)"
    sudo pacman -Syu --needed base-devel git
    command -v yay >/dev/null && return 0
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
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
    command -v yay >/dev/null || step_yay
    local pkgs; list pkgs aur.txt
    yay -S --needed "${pkgs[@]}"
}

# Awesome は Lua 5.4 で組む (AUR の既定は 5.5 だが、Awesome が対応しているのは 5.4 まで)。
# 手順は ~/.local/bin/awesome-git-lua54 (更新するときもそれを実行する)
step_awesome() {
    info "Awesome (awesome-git を Lua 5.4 で)"
    if pacman -Qi awesome-git 2>/dev/null | grep -q 'lua54-lgi'; then
        echo "Lua 5.4 版が入っているので飛ばす (更新は awesome-git-lua54)"
        return 0
    fi
    bash "$REPO/dot_local/bin/executable_awesome-git-lua54"
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
    for f in greetd/config.toml pam.d/greetd systemd/timesyncd.conf.d/nict.conf udev/rules.d/50-pci-runtime-pm.rules \
             systemd/zram-generator.conf sysctl.d/99-tuning.conf systemd/system/paccache.service.d/keep2.conf; do
        sudo install -D -m644 "$REPO/system/etc/$f" "/etc/$f"
    done
    # systemd-boot を使っているときだけ、systemd の更新時にブートローダーも更新する
    if bootctl is-installed >/dev/null 2>&1; then
        sudo install -D -m644 "$REPO/system/etc/pacman.d/hooks/systemd-boot.hook" /etc/pacman.d/hooks/systemd-boot.hook
    fi
}

# packages/services.txt のサービスを 1 つずつ有効にする (起動は再起動のときに行う)
# 入っていないもの (例: AMD の PC の thermald) は飛ばし、失敗しても残りは続ける
step_services() {
    info "サービスの有効化"
    local line unit ok=() skipped=() failed=()
    local -a sysctl
    while read -r line; do
        if [[ $line == user:* ]]; then
            unit=${line#user:}; sysctl=(systemctl --user)
        else
            unit=$line; sysctl=(sudo systemctl)
        fi
        if ! "${sysctl[@]}" cat "$unit" >/dev/null 2>&1; then
            skipped+=("$unit")
        elif "${sysctl[@]}" enable "$unit" >/dev/null 2>&1; then
            ok+=("$unit")
        else
            failed+=("$unit")
        fi
    done < <(grep -vhE '^\s*(#|$)' "$REPO/packages/services.txt")
    echo "有効にした: ${ok[*]:-なし}"
    (( ${#skipped[@]} )) && echo "入っていないので飛ばした: ${skipped[*]}"
    (( ${#failed[@]} )) && warn "有効にできなかった: ${failed[*]}"

    # ファイアウォール: 外からの接続はすべて拒否する (SSH サーバーも動かさない)
    # 設定ファイルに書くだけにして、次の起動から有効にする。
    # (直後に ufw enable すると、カーネルが更新された直後はモジュールが読めずに失敗するため)
    if command -v ufw >/dev/null; then
        sudo ufw default deny incoming >/dev/null
        sudo ufw default allow outgoing >/dev/null
        sudo sed -i 's/^ENABLED=no/ENABLED=yes/' /etc/ufw/ufw.conf
        if [[ -d /usr/lib/modules/$(uname -r) ]]; then
            sudo ufw --force enable >/dev/null && echo "ファイアウォールを有効にした"
        else
            echo "ファイアウォールは次の起動から有効になります (カーネルが更新されたため)"
        fi
    fi
    (( ${#failed[@]} == 0 ))
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
    # アプリの配色をダークに (GTK4 / ブラウザなどは gsettings を見る。GTK3 は settings.ini、Qt は qt5ct/qt6ct)
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
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
    local s failed=()
    for s in "${steps[@]}"; do
        declare -F "step_$s" >/dev/null || { echo "不明な手順: $s (使えるもの: ${STEPS[*]})"; exit 1; }
    done
    # 1 つの手順が失敗しても残りは続け、最後にまとめて知らせる
    for s in "${steps[@]}"; do
        set +e
        ( set -e; "step_$s" )
        local rc=$?
        set -e
        (( rc == 0 )) || { warn "手順 $s が失敗しました"; failed+=("$s"); }
    done
    if (( ${#failed[@]} )); then
        warn "失敗した手順: ${failed[*]}"
        echo "原因を直してから、その手順だけやり直せます:  $0 ${failed[*]}"
        exit 1
    fi
    [[ -d /usr/lib/modules/$(uname -r) ]] || warn "カーネルが更新されました。再起動してください"
    info "完了。再起動するとログイン画面 (tuigreet) から Awesome が起動します"
}

main "$@"
