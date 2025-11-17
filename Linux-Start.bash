#!/bin/bash
#
# Linuxデスクトップ環境セットアップスクリプト (Debian/Ubuntu他主要ディストロ対応)
#

set -euo pipefail

# --- グローバル変数 ---
SUDO=""
PM=""
DISTRO_ID=""

# --- 基本ユーティリティ関数 ---
available()   { command -v "$1" >/dev/null 2>&1; }
show()        { echo "+ $*"; "$@"; }
error()       { echo "エラー: $1" >&2; exit 1; }
step()        { echo -e "\n---- $1 ----"; }

# --- OS情報取得 ---
show_os_info() {
    step "現在のOS情報"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=${ID:-unknown}
        echo "OS: ${NAME:-不明} (ID: $DISTRO_ID)"
        echo "バージョン: ${VERSION:-不明}"
    else
        DISTRO_ID="unknown"
        echo "OS: $(uname -s)"
        echo "カーネル: $(uname -r)"
    fi
}

# --- 各ディストリ用アップデート/インストール実体(デフォルトはエラー) ---
update_system()      { error "update_system関数が定義されていません。"; }
install_packages()   { error "install_packages関数が定義されていません。"; }

# --- ディストリ毎の実体を定義 ---
define_distro_actions() {
    step "ディストリビューション固有の処理を準備"
    if available apt-get; then
        PM="apt"
        update_system() { show $SUDO apt-get update && show $SUDO apt-get upgrade -y; }
        install_packages() {
            local packages=(locales fcitx-mozc exfat-fuse wget ffmpeg ruby-full python3 python3-pip)
            [[ "$DISTRO_ID" == "debian" ]] && { echo "Debian検出: task-japanese-desktop追加"; packages+=("task-japanese-desktop"); }
            show $SUDO apt-get install -y locales
            show $SUDO apt-get install -y "${packages[@]}"
        }
    elif available dnf; then
        PM="dnf"
        update_system()      { show $SUDO dnf upgrade -y; }
        install_packages()   { show $SUDO dnf install -y glibc-langpack-ja fcitx5-mozc google-noto-cjk-fonts exfat-utils wget ffmpeg ruby python3 python3-pip; }
    elif available yum; then
        PM="yum"
        update_system()      { show $SUDO yum update -y; }
        install_packages()   { show $SUDO yum install -y langpacks-ja fcitx-mozc vlgothic-p-fonts exfat-utils wget ffmpeg ruby python3 python3-pip; }
    elif available pacman; then
        PM="pacman"
        update_system()      { show $SUDO pacman -Syu --noconfirm; }
        install_packages()   { show $SUDO pacman -S --noconfirm fcitx5-mozc noto-fonts-cjk exfat-utils wget ffmpeg ruby python python-pip; }
    elif available zypper; then
        PM="zypper"
        update_system()      { show $SUDO zypper refresh && show $SUDO zypper update -y; }
        install_packages()   { show $SUDO zypper install -y glibc-locale fcitx-mozc noto-sans-cjk-jp-fonts exfat-utils wget ffmpeg ruby python3 python3-pip; }
    else
        error "サポートされていないパッケージマネージャです。"
    fi
    echo "パッケージマネージャ '$PM' を検出しました。"
}

# --- ロケール/タイムゾーン設定 ---
setup_localization() {
    local use_systemd=false
    [ -d /run/systemd/system ] && use_systemd=true

    step "タイムゾーン設定"
    if [ "$PM" = "apt" ]; then
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
            echo "Ubuntuでは設定済み可能性が高いためスキップ"
        else
            show $SUDO dpkg-reconfigure tzdata
        fi
    elif [ "$use_systemd" = true ] && available timedatectl; then
        show $SUDO timedatectl set-timezone Asia/Tokyo
    elif [ -f /usr/share/zoneinfo/Asia/Tokyo ]; then
        show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
    fi

    step "ロケールを日本語に設定"
    if [ "$PM" = "apt" ]; then
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
            echo "Ubuntuでは設定済み可能性が高いためスキップ"
        else
            show $SUDO dpkg-reconfigure locales
        fi
    elif [ "$use_systemd" = true ] && available localectl; then
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        echo "LANG=ja_JP.UTF-8" | show $SUDO tee /etc/locale.conf > /dev/null
    fi
}

# --- Braveブラウザ自動インストール ---
install_brave_browser() {
    step "Braveブラウザのインストール"
    local brave_installer
    brave_installer=$(mktemp)
    trap 'rm -f "$brave_installer"' EXIT
    if available wget; then
        show wget https://dl.brave.com/install.sh -O "$brave_installer"
        show $SUDO sh "$brave_installer"
    else
        echo "wget未検出: Braveブラウザのインストールをスキップ"
    fi
    rm -f "$brave_installer"
    trap - EXIT
}

# --- yt-dlpインストール ---
install_ytdlp() {
    step "yt-dlpのインストール"
    if available wget; then
        show $SUDO wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
        show $SUDO chmod a+rx /usr/local/bin/yt-dlp
    fi
}

# --- Narou.rb & 互換性調整 ---
install_narou_rb() {
    step "Narou.rbのインストール＋互換性対策"
    show $SUDO gem install narou
    show $SUDO gem install tilt -v 2.4.0
    show $SUDO gem uninstall tilt -v 2.6.1 || true
}

# --- Narou.rb設定yaml自動コピー ---
copy_narou_yaml_config() {
    step "Narou.rbの設定ファイル(yaml)を配置"
    local config_src_dir="$HOME/linux-startP"
    echo "Narou.rbインストール先探索..."
    local gem_base_dir narou_gem_path target_dir
    if ! gem_base_dir=$(ruby -e 'print Gem.dir' 2>/dev/null); then
        error "RubyのGemディレクトリが取得できません"
    fi
    narou_gem_path=$(find "$gem_base_dir/gems" -maxdepth 1 -type d -name "narou-*" | sort -V | tail -n 1)
    target_dir="${narou_gem_path:+${narou_gem_path}/webnovel/}"

    if [ ! -d "$config_src_dir" ]; then
        echo "yaml元ディレクトリ $config_src_dir 不在。スキップ。"
    elif [ -z "$target_dir" ] || [ ! -d "$target_dir" ]; then
        echo "コピー先 $target_dir が存在しません。スキップ。"
    else
        for yaml in novel18.syosetu.com.yaml ncode.syosetu.com.yaml; do
            [ -f "$config_src_dir/$yaml" ] && show $SUDO cp "$config_src_dir/$yaml" "$target_dir" && echo "$yaml をコピーしました。"
        done
    fi
}

# --- メイン ---
main() {
    [ "$(id -u)" -eq 0 ] && SUDO="" || { SUDO="sudo"; $SUDO -v; echo "sudo権限を使用します。"; }
    show_os_info
    define_distro_actions
    step "システムのアップデート"
    update_system
    step "必要なパッケージのインストール"
    install_packages
    setup_localization
    install_brave_browser
    install_ytdlp
    install_narou_rb
    copy_narou_yaml_config
    echo -e "\n---- セットアップが完了しました ----"
}

main "$@"
