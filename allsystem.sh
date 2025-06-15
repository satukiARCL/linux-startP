#!/bin/sh
set -eu

# ユーティリティ関数
available() { command -v "$1" >/dev/null; }
show() { (set -x; "$@"); }
error() { echo "Error: $1" >&2; exit 1; }

# パッケージマネージャの検出
detect_package_manager() {
    if available apt-get; then
        echo "apt"
    elif available yum; then
        echo "yum"
    elif available dnf; then
        echo "dnf"
    elif available pacman; then
        echo "pacman"
    elif available zypper; then
        echo "zypper"
    else
        error "Unsupported package manager. Please install one of apt, yum, dnf, pacman, or zypper."
    fi
}

# ステップを表示する関数
step() {
    echo "\n---- ${1} ----"
}

main() {
    # スクリプトの実行ユーザーを確認
    case "$(whoami)" in
        root) sudo="";;
        *) sudo="sudo";;
    esac

    # パッケージマネージャの確認
    PM=$(detect_package_manager)

    # システムのアップデート
    step "Updating System"
    case "$PM" in
        apt) show $sudo apt update && show $sudo apt upgrade -y ;;
        yum) show $sudo yum update -y ;;
        dnf) show $sudo dnf upgrade -y ;;
        pacman) show $sudo pacman -Syu ;;
        zypper) show $sudo zypper refresh && show $sudo zypper update ;;
    esac

    # タイムゾーンの設定
    step "Setting Timezone to Asia/Tokyo"
    show $sudo cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime || true

    # ロケールの設定
    step "Setting Locale to Japanese"
    show $sudo apt install -y locales || true
    show $sudo locale-gen ja_JP.UTF-8 || true
    echo "LANG=ja_JP.UTF-8" | $sudo tee /etc/default/locale
    echo "LANGUAGE=ja_JP.UTF-8" | $sudo tee -a /etc/default/locale

    # 必要なパッケージのインストール
    step "Installing Necessary Packages"
    show $sudo apt install -y fcitx-mozc task-japanese-desktop exfat-fuse || true

    # Braveブラウザのインストール
    step "Installing Brave Browser"
    show wget https://dl.brave.com/install.sh && $sudo sh install.sh || true

    # yt-dlpのインストール
    step "Installing yt-dlp"
    show $sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp || true
    show $sudo chmod a+rx /usr/local/bin/yt-dlp || true

    # ffmpegのインストール
    step "Installing FFmpeg"
    show $sudo apt install -y ffmpeg || true

    # Ruby & Narou.rb のインストール
    step "Installing Ruby and Narou.rb"
    show $sudo apt install -y ruby-full || true
    show $sudo gem install narou || true

    # Pythonのインストール
    step "Installing Python and Pip"
    show $sudo apt-get install -y python3 python3-distutils python3-pip || true

    echo "\n---- Installation completed. Please check for any errors in the output. ----"
}

main
