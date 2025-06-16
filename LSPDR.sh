#!/bin/bash
#
# このスクリプトは、Linuxデスクトップ環境に日本語環境と便利なツールをセットアップします。
# systemdの有無を検出し、WSLやDockerコンテナのような環境にも対応します。
#

# スクリプトの堅牢性を高める設定
set -euo pipefail

# --- グローバル変数 ---
SUDO=""
PM=""

# --- ユーティリティ関数 ---
available() { command -v "$1" >/dev/null 2>&1; }
show() { echo "+ $*"; "$@"; }
error() { echo "エラー: $1" >&2; exit 1; }
step() { echo -e "\n---- $1 ----"; }

# --- OS・ディストリビューション固有の処理 ---

# OS情報を表示する
show_os_info() {
    step "現在のOS情報"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "オペレーティングシステム: ${NAME:-不明}"
        echo "バージョン: ${VERSION:-不明}"
    else
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
    fi
}

# システムをアップデートする関数（内容は動的に定義される）
update_system() { error "update_system関数が定義されていません。"; }
# パッケージをインストールする関数（内容は動的に定義される）
install_packages() { error "install_packages関数が定義されていません。"; }

# パッケージマネージャを検出し、それに応じた処理関数を定義する
define_distro_actions() {
    step "ディストリビューション固有の処理を準備"

    if available apt-get; then
        PM="apt"
        update_system() { show $SUDO apt-get update && show $SUDO apt-get upgrade -y; }
        install_packages() {
            local packages=(
                locales fcitx-mozc task-japanese-desktop exfat-fuse
                wget ffmpeg ruby-full python3 python3-pip
            )
            # 最初にlocalesをインストールしないとlocale-genで失敗することがある
            show $SUDO apt-get install -y locales
            show $SUDO apt-get install -y "${packages[@]}"
        }
    elif available dnf; then
        PM="dnf"
        update_system() { show $SUDO dnf upgrade -y; }
        install_packages() {
            local packages=(
                glibc-langpack-ja fcitx5-mozc google-noto-cjk-fonts
                exfat-utils wget ffmpeg ruby python3 python3-pip
            )
            show $SUDO dnf install -y "${packages[@]}"
        }
    # ... 他のパッケージマネージャの定義は省略しません ...
    elif available yum; then
        PM="yum"; update_system() { show $SUDO yum update -y; }; install_packages() { local packages=(langpacks-ja fcitx-mozc vlgothic-p-fonts exfat-utils wget ffmpeg ruby python3 python3-pip); show $SUDO yum install -y "${packages[@]}"; }
    elif available pacman; then
        PM="pacman"; update_system() { show $SUDO pacman -Syu --noconfirm; }; install_packages() { local packages=(fcitx5-mozc noto-fonts-cjk exfat-utils wget ffmpeg ruby python python-pip); show $SUDO pacman -S --noconfirm "${packages[@]}"; }
    elif available zypper; then
        PM="zypper"; update_system() { show $SUDO zypper refresh && show $SUDO zypper update -y; }; install_packages() { local packages=(glibc-locale fcitx-mozc noto-sans-cjk-jp-fonts exfat-utils wget ffmpeg ruby python3 python3-pip); show $SUDO zypper install -y "${packages[@]}"; }
    else
        error "サポートされていないパッケージマネージャです。apt, dnf, yum, pacman, zypper のいずれかが必要です。"
    fi
    echo "パッケージマネージャ '$PM' を検出し、処理を準備しました。"
}

# タイムゾーンとロケールを設定する (systemd対応版)
setup_localization() {
    # systemdが稼働しているかのフラグ
    local use_systemd=false
    if [ -d /run/systemd/system ]; then
        use_systemd=true
    fi

    step "タイムゾーンを Asia/Tokyo に設定"
    if [ "$use_systemd" = true ] && available timedatectl; then
        show $SUDO timedatectl set-timezone Asia/Tokyo
    else
        echo "systemdが検出されなかったため、従来の方法でタイムゾーンを設定します。"
        if [ -f /usr/share/zoneinfo/Asia/Tokyo ]; then
            show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
        else
            echo "警告: /usr/share/zoneinfo/Asia/Tokyo が見つかりません。タイムゾーン設定をスキップします。"
        fi
    fi

    step "ロケールを日本語に設定"
    if [ "$PM" = "apt" ]; then
        # Debian/Ubuntu系は専用の方法が最も確実
        show $SUDO locale-gen ja_JP.UTF-8
        show $SUDO update-locale LANG=ja_JP.UTF-8
    elif [ "$use_systemd" = true ] && available localectl; then
        # systemdが利用可能なその他のディストリビューション
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        # systemdが利用できない場合の汎用的なフォールバック
        echo "systemdが検出されなかったため、従来の方法でロケールを設定します。"
        echo "LANG=ja_JP.UTF-8" | show $SUDO tee /etc/locale.conf > /dev/null
        echo "警告: ロケールを/etc/locale.confに書き込みました。環境によっては.bash_profile等への追記も必要です。"
    fi
}


# --- メイン処理 ---
main() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
        $SUDO -v
        echo "このスクリプトはシステムの変更を行うため、sudo権限を使用します。"
    fi

    show_os_info
    define_distro_actions

    step "システムのアップデート"
    update_system

    step "必要なパッケージのインストール"
    install_packages
    
    # パッケージインストール後にロケール設定を行う
    setup_localization

    step "Braveブラウザのインストール"
    local brave_installer
    brave_installer=$(mktemp)
    trap 'rm -f "$brave_installer"' EXIT
    show wget https://dl.brave.com/install.sh -O "$brave_installer"
    show $SUDO sh "$brave_installer"
    rm -f "$brave_installer"
    trap - EXIT

    step "yt-dlpのインストール"
    show $SUDO wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
    show $SUDO chmod a+rx /usr/local/bin/yt-dlp

    step "Narou.rbのインストール"
    show $SUDO gem install narou

    echo -e "\n---- セットアップが完了しました ----"
    echo "出力内容にエラーがないか確認してください。"
    echo "日本語入力やフォントを有効にするには、システムの再起動や再ログインが必要な場合があります。"
}

main "$@"
