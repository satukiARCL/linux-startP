#!/bin/sh
set -eu

# ユーティリティ関数
available() { command -v "$1" >/dev/null; }
show() { (set -x; "$@"); }
error() { echo "エラー: $1" >&2; exit 1; }

# OS情報の表示
show_os_info() {
    echo "\n---- 現在のOS情報 ----"
    if [ -f /etc/os-release ]; then
        # /etc/os-releaseがある場合は、その内容を表示
        . /etc/os-release
        echo "オペレーティングシステム: $NAME"
        echo "バージョン: $VERSION"
    else
        # unameコマンドで情報を取得
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
    fi
}

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
        error "サポートされていないパッケージマネージャです。apt, yum, dnf, pacman, または zypper のいずれかをインストールしてください。"
    fi
}

# ステップを表示する関数
step() {
    echo "\n---- ${1} ----"
}

main() {
    # 現在のOS情報を表示
    show_os_info

    # スクリプトの実行ユーザーを確認
    case "$(whoami)" in
        root) sudo="";;
        *) sudo="sudo";;
    esac

    # パッケージマネージャの確認
    PM=$(detect_package_manager)

    # システムのアップデート
    step "システムのアップデート"
    case "$PM" in
        apt) show $sudo apt update && show $sudo apt upgrade -y ;;
        yum) show $sudo yum update -y ;;
        dnf) show $sudo dnf upgrade -y ;;
        pacman) show $sudo pacman -Syu ;;
        zypper) show $sudo zypper refresh && show $sudo zypper update ;;
    esac

    # タイムゾーンの設定
    step "タイムゾーンを Asia/Tokyo に設定"
    show $sudo cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime || true

    # ロケールの設定
    step "ロケールを日本語に設定"
    show $sudo apt install -y locales || true
    show $sudo locale-gen ja_JP.UTF-8 || true
    echo "LANG=ja_JP.UTF-8" | $sudo tee /etc/default/locale
    echo "LANGUAGE=ja_JP.UTF-8" | $sudo tee -a /etc/default/locale

    # 必要なパッケージのインストール
    step "必要なパッケージのインストール"
    show $sudo apt install -y fcitx-mozc task-japanese-desktop exfat-fuse || true

    # Braveブラウザのインストール
    step "Braveブラウザのインストール"
    show wget https://dl.brave.com/install.sh && $sudo sh install.sh || true

    # yt-dlpのインストール
    step "yt-dlpのインストール"
    show $sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp || true
    show $sudo chmod a+rx /usr/local/bin/yt-dlp || true

    # ffmpegのインストール
    step "FFmpegのインストール"
    show $sudo apt install -y ffmpeg || true

    # Ruby & Narou.rb のインストール
    step "RubyとNarou.rbのインストール"
    show $sudo apt install -y ruby-full || true
    show $sudo gem install narou || true

    # Pythonのインストール
    step "PythonとPipのインストール"
    show $sudo apt-get install -y python3 python3-distutils python3-pip || true

    echo "\n---- インストールが完了しました。出力内容にエラーがないか確認してください。 ----"
}

main
