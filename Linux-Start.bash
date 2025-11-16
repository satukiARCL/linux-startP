#!/bin/bash
#
# このスクリプトは、Linuxデスクトップ環境に日本語環境と便利なツールをセットアップします。
# systemdの有無を検出し、WSLやDockerコンテナのような環境にも対応します。
# shellcheck disable=SC1091,SC2317
# SC1091: /etc/os-releaseの動的読み込みは必要なため許可します。
# SC2317: 動的に上書き・呼び出しされる関数のダミー定義なので意図的です。

set -euo pipefail

# --- グローバル変数 ---
SUDO=""
PM=""

# --- ユーティリティ関数 ---
available()      { command -v "$1" >/dev/null 2>&1; }
show()           { echo "+ $*"; "$@"; }
error()          { echo "エラー: $1" >&2; exit 1; }
step()           { echo -e "\n---- $1 ----"; }

# --- OS情報を表示する関数 ---
show_os_info() {
    step "現在のOS情報"
    # shellcheck disable=SC1091
    if [ -f /etc/os-release ]; then
        # shellcheck source=/etc/os-release
        . /etc/os-release
        echo "オペレーティングシステム: ${NAME:-不明}"
        echo "バージョン: ${VERSION:-不明}"
    else
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
    fi
}

# --- システムアップデート・パッケージ導入関数 (ディストロごとに生成) ---
# shellcheck disable=SC2317
update_system()        { error "update_system関数が定義されていません。"; }
# shellcheck disable=SC2317
install_packages()     { error "install_packages関数が定義されていません。"; }

define_distro_actions() {
    step "ディストリビューション固有の処理を準備"

    if available apt-get; then
        PM="apt"
        update_system()    { show $SUDO apt-get update && show $SUDO apt-get upgrade -y; }
        install_packages() {
            local packages
            packages=(
                locales fcitx-mozc task-japanese-desktop exfat-fuse
                wget ffmpeg ruby-full python3 python3-pip
                git xinput tlp tlp-rdw gparted qdirstat meld curl fuse3
            )
            show $SUDO apt-get install -y locales
            show $SUDO apt-get install -y "${packages[@]}"
        }
    elif available dnf; then
        PM="dnf"
        update_system()    { show $SUDO dnf upgrade -y; }
        install_packages() {
            local packages
            packages=(
                glibc-langpack-ja fcitx5-mozc google-noto-cjk-fonts
                exfat-utils wget ffmpeg ruby python3 python3-pip
                git tlp gparted meld curl fuse3
            )
            show $SUDO dnf install -y "${packages[@]}"
        }
    elif available yum; then
        PM="yum"
        update_system()    { show $SUDO yum update -y; }
        install_packages() {
            local packages
            packages=(langpacks-ja fcitx-mozc vlgothic-p-fonts exfat-utils wget ffmpeg ruby python3 python3-pip git tlp gparted meld curl fuse3)
            show $SUDO yum install -y "${packages[@]}"
        }
    elif available pacman; then
        PM="pacman"
        update_system()    { show $SUDO pacman -Syu --noconfirm; }
        install_packages() {
            local packages
            packages=(fcitx5-mozc noto-fonts-cjk exfat-utils wget ffmpeg ruby python python-pip git tlp gparted meld curl fuse3)
            show $SUDO pacman -S --noconfirm "${packages[@]}"
        }
    elif available zypper; then
        PM="zypper"
        update_system()    { show $SUDO zypper refresh && show $SUDO zypper update -y; }
        install_packages() {
            local packages
            packages=(glibc-locale fcitx-mozc noto-sans-cjk-jp-fonts exfat-utils wget ffmpeg ruby python3 python3-pip git tlp gparted meld curl fuse3)
            show $SUDO zypper install -y "${packages[@]}"
        }
    else
        error "サポートされていないパッケージマネージャです。apt, dnf, yum, pacman, zypper のいずれかが必要です。"
    fi
    echo "パッケージマネージャ '$PM' を検出し、処理を準備しました。"
}

# --- タイムゾーンとロケールの設定 ---
setup_localization() {
    local use_systemd=false
    if [ -d /run/systemd/system ]; then use_systemd=true; fi

    step "タイムゾーンを設定"
    if [ "$PM" = "apt" ]; then
        echo "Debian/Ubuntu系: 対話的にタイムゾーンを設定"
        show $SUDO dpkg-reconfigure tzdata
    elif [ "$use_systemd" = true ] && available timedatectl; then
        echo "systemd環境: Asia/Tokyo に設定"
        show $SUDO timedatectl set-timezone Asia/Tokyo
    else
        echo "従来の方法でタイムゾーンを設定"
        if [ -f /usr/share/zoneinfo/Asia/Tokyo ]; then
            show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
        else
            echo "警告: /usr/share/zoneinfo/Asia/Tokyo が見つかりません"
        fi
    fi

    step "ロケールを日本語に設定"
    if [ "$PM" = "apt" ]; then
        echo "Debian/Ubuntu系: 対話的にロケールを設定"
        show $SUDO dpkg-reconfigure locales
    elif [ "$use_systemd" = true ] && available localectl; then
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        echo "従来の方法でロケールを設定"
        echo "LANG=ja_JP.UTF-8" | show $SUDO tee /etc/locale.conf > /dev/null
        echo "警告: /etc/locale.confに追記。必要に応じて.bash_profile等へも"
    fi
}

# --- メイン処理 ---
main() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
        $SUDO -v
        echo "sudo権限を使用します。"
    fi

    show_os_info
    define_distro_actions

    step "システムのアップデート"
    update_system

    step "必要なパッケージのインストール"
    install_packages

    setup_localization

    step "Braveブラウザのインストール"
    local brave_installer
    brave_installer=$(mktemp)
    trap 'rm -f "$brave_installer"' EXIT
    show wget https://dl.brave.com/install.sh -O "$brave_installer"
    show $SUDO sh "$brave_installer"
    rm -f "$brave_installer"
    trap - EXIT

    step "Google Chromeのインストール (Debian/Ubuntu系のみ)"
    if [ "$PM" = "apt" ]; then
        local chrome_deb
        chrome_deb=$(mktemp --suffix=.deb)
        trap 'rm -f "$chrome_deb"' EXIT
        show wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "$chrome_deb"
        show $SUDO apt install -y "$chrome_deb"
        rm -f "$chrome_deb"
        trap - EXIT
    else
        echo "非Debian系: Chromeインストールスキップ"
    fi

    step "yt-dlpのインストール"
    show $SUDO wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
    show $SUDO chmod a+rx /usr/local/bin/yt-dlp

    step "rcloneのインストール"
    if available curl; then
        echo "+ curl https://rclone.org/install.sh | $SUDO bash"
        curl https://rclone.org/install.sh | $SUDO bash
    else
        echo "警告: rcloneのインストールにcurlが必要"
    fi

    step "Narou.rbのインストール"
    show $SUDO gem install narou

    step "Narou.rbの互換性設定（tilt バージョン調整）"
    show $SUDO gem install tilt -v 2.4.0
    show $SUDO gem uninstall tilt -v 2.6.1 || true

    step "Narou.rbの設定ファイル（yaml）を配置"
    local config_src_dir="$HOME/linux-startP"
    local target_dir="/var/lib/gems/3.1.0/gems/narou-3.9.1/webnovel/"
    if [ ! -d "$config_src_dir" ]; then
        echo "警告: 設定ファイル元 $config_src_dir 不在、コピーせず"
    elif [ ! -d "$target_dir" ]; then
        echo "警告: Narou.rbインストール先 $target_dir 不在"
    else
        for yamlfile in novel18.syosetu.com.yaml ncode.syosetu.com.yaml; do
            if [ -f "$config_src_dir/$yamlfile" ]; then
                show $SUDO cp "$config_src_dir/$yamlfile" "$target_dir"
            else
                echo "警告: $config_src_dir/$yamlfile 不在"
            fi
        done
    fi

    step "TLP (省電力) サービスの開始"
    if available tlp; then
        echo "TLPを起動します..."
        show $SUDO tlp start
    else
        echo "TLPが見つからず、スキップ"
    fi

    echo -e "\n---- セットアップが完了しました ----"
    echo "出力にエラーがないか確認してください。日本語入力やフォント設定有効化には再起動が必要な場合があります。"
}

main "$@"
