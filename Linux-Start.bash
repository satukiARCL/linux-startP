#!/bin/bash
#
# このスクリプトは、Linuxデスクトップ環境に日本語環境と便利なツールをセットアップします。
# systemdの有無を検出し、WSLやDockerコンテナのような環境にも対応します。
#

# スクリプトの堅牢性を高める設定
set -euo pipefail [cite: 1]

# --- グローバル変数 ---
SUDO=""
PM=""

# --- ユーティリティ関数 ---
available() { command -v "$1" >/dev/null 2>&1; [cite: 2] }
show() { echo "+ $*"; "$@"; }
error() { echo "エラー: $1" >&2; exit 1; [cite: 3] }
step() { echo -e "\n---- $1 ----"; }

# --- OS・ディストリビューション固有の処理 ---

# OS情報を表示する
show_os_info() {
    step "現在のOS情報"
    if [ -f /etc/os-release ]; [cite: 4]
    then
        . /etc/os-release
        echo "オペレーティングシステム: ${NAME:-不明}"
        echo "バージョン: ${VERSION:-不明}"
    else
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
    fi
}

# システムをアップデートする関数（内容は動的に定義される）
update_system() { error "update_system関数が定義されていません。"; [cite: 5] }
# パッケージをインストールする関数（内容は動的に定義される）
install_packages() { error "install_packages関数が定義されていません。"; }

# パッケージマネージャを検出し、それに応じた処理関数を定義する
define_distro_actions() {
    step "ディストリビューション固有の処理を準備"

    if available apt-get; 
    then
        PM="apt"
        update_system() { show $SUDO apt-get update && show $SUDO apt-get upgrade -y; [cite: 7] }
        install_packages() {
            local packages=(
                locales fcitx-mozc task-japanese-desktop exfat-fuse
                wget ffmpeg ruby-full python3 python3-pip
            )
            # 最初にlocalesをインストールしないとlocale-genで失敗することがある
            show $SUDO apt-get install -y locales [cite: 8]
            show $SUDO apt-get install -y "${packages[@]}"
        }
    elif available dnf; [cite: 9]
    then
        PM="dnf"
        update_system() { show $SUDO dnf upgrade -y; [cite: 10] }
        install_packages() {
            local packages=(
                glibc-langpack-ja fcitx5-mozc google-noto-cjk-fonts
                exfat-utils wget ffmpeg ruby python3 python3-pip
            )
            show $SUDO dnf install -y "${packages[@]}"
        }
  
    # ... 他のパッケージマネージャの定義は省略しません ... [cite: 11]
    elif available yum; [cite: 12]
    then
        PM="yum"; update_system() { show $SUDO yum update -y; }; [cite: 13] install_packages() { local packages=(langpacks-ja fcitx-mozc vlgothic-p-fonts exfat-utils wget ffmpeg ruby python3 python3-pip); show $SUDO yum install -y "${packages[@]}"; [cite: 14] }
    elif available pacman; then
        PM="pacman"; [cite: 15] update_system() { show $SUDO pacman -Syu --noconfirm; }; install_packages() { local packages=(fcitx5-mozc noto-fonts-cjk exfat-utils wget ffmpeg ruby python python-pip); [cite: 16] show $SUDO pacman -S --noconfirm "${packages[@]}"; }
    elif available zypper; [cite: 17]
    then
        PM="zypper"; update_system() { show $SUDO zypper refresh && show $SUDO zypper update -y; [cite: 18] }; install_packages() { local packages=(glibc-locale fcitx-mozc noto-sans-cjk-jp-fonts exfat-utils wget ffmpeg ruby python3 python3-pip); show $SUDO zypper install -y "${packages[@]}"; [cite: 19] }
    else
        error "サポートされていないパッケージマネージャです。apt, dnf, yum, pacman, zypper のいずれかが必要です。"
    fi
    echo "パッケージマネージャ '$PM' を検出し、処理を準備しました。"
}

# タイムゾーンとロケールを設定する (systemd対応版)
setup_localization() {
    # systemdが稼働しているかのフラグ
    local use_systemd=false
    if [ -d /run/systemd/system ]; [cite: 20]
    then
        use_systemd=true
    fi

    step "タイムゾーンを設定"
    if [ "$PM" = "apt" ];
    then
        echo "Debian/Ubuntu系を検出しました。対話的にタイムゾーンを設定します..."
        show $SUDO dpkg-reconfigure tzdata
    elif [ "$use_systemd" = true ] && available timedatectl;
    then
        # systemd環境の場合 (元のダミーコード [cite: 21] の箇所)
        echo "systemd環境を検出しました。タイムゾーンを Asia/Tokyo に設定します。"
        show $SUDO timedatectl set-timezone Asia/Tokyo
    else
        echo "systemdが検出されなかったため、従来の方法でタイムゾーンを設定します。"
        if [ -f /usr/share/zoneinfo/Asia/Tokyo ]; [cite: 22]
        then
            show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
        else
            echo "警告: /usr/share/zoneinfo/Asia/Tokyo が見つかりません。タイムゾーン設定をスキップします。"
        fi
    fi

    step "ロケールを日本語に設定"
    if [ "$PM" = "apt" ]; [cite: 23]
    then
        # Debian/Ubuntu系はご要望の対話的設定を使用 [cite: 23]
        echo "Debian/Ubuntu系を検出しました。対話的にロケールを設定します..."
        show $SUDO dpkg-reconfigure locales
    elif [ "$use_systemd" = true ] && available localectl; [cite: 24]
    then
        # systemdが利用可能なその他のディストリビューション
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        # systemdが利用できない場合の汎用的なフォールバック
        echo "systemdが検出されなかったため、従来の方法でロケールを設定します。"
        echo "LANG=ja_JP.UTF-8" | [cite: 25] show $SUDO tee /etc/locale.conf > /dev/null
        echo "警告: ロケールを/etc/locale.confに書き込みました。環境によっては.bash_profile等への追記も必要です。"
    fi
}


# --- メイン処理 ---
main() {
    if [ "$(id -u)" -eq 0 ]; [cite: 26]
    then
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
    trap 'rm -f "$brave_installer"' EXIT [cite: 27]
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
