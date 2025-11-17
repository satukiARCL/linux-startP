#!/bin/bash
#
# Linuxデスクトップ環境セットアップスクリプト (Debian/Ubuntu両対応版)
#

# スクリプトの堅牢性を高める設定
set -euo pipefail

# --- グローバル変数 ---
SUDO=""
PM=""
DISTRO_ID=""

# --- ユーティリティ関数 ---
available() { command -v "$1" >/dev/null 2>&1; }
show() { echo "+ $*"; "$@"; }
error() { echo "エラー: $1" >&2; exit 1; }
step() { echo -e "\n---- $1 ----"; }

# --- OS・ディストリビューション固有の処理 ---

show_os_info() {
    step "現在のOS情報"
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO_ID=${ID:-unknown}
        echo "オペレーティングシステム: ${NAME:-不明} (ID: $DISTRO_ID)"
        echo "バージョン: ${VERSION:-不明}"
    else
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
        DISTRO_ID="unknown"
    fi
}

# 初期定義（安全策としてのスタブ）。後で上書きされるためShellcheckの警告を抑制
# shellcheck disable=SC2329
update_system() { error "update_system関数が定義されていません。"; }
# shellcheck disable=SC2329
install_packages() { error "install_packages関数が定義されていません。"; }

define_distro_actions() {
    step "ディストリビューション固有の処理を準備"

    if available apt-get; then
        PM="apt"
        # ここで関数を上書き（再定義）する
        update_system() { show $SUDO apt-get update && show $SUDO apt-get upgrade -y; }
        
        install_packages() {
            # 共通パッケージ
            local packages=(
                locales fcitx-mozc exfat-fuse
                wget ffmpeg ruby-full python3 python3-pip
            )

            # ディストリビューション別のパッケージ分岐
            if [[ "$DISTRO_ID" == "debian" ]]; then
                echo "Debianを検出: task-japanese-desktop を追加します。"
                packages+=("task-japanese-desktop")
            elif [[ "$DISTRO_ID" == "ubuntu" ]]; then
                echo "Ubuntuを検出: task-japanese-desktop は除外します。"
                # Ubuntuは標準で日本語環境が整っていることが多いが、念の為 language-pack-ja を入れても良い
                # packages+=("language-pack-ja") 
            else
                echo "Debian/Ubuntu以外 ($DISTRO_ID) を検出: 共通パッケージのみインストールします。"
            fi

            # 最初にlocalesをインストール
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
    elif available yum; then
        PM="yum"
        update_system() { show $SUDO yum update -y; }
        install_packages() {
            local packages=(langpacks-ja fcitx-mozc vlgothic-p-fonts exfat-utils wget ffmpeg ruby python3 python3-pip)
            show $SUDO yum install -y "${packages[@]}"
        }
    elif available pacman; then
        PM="pacman"
        update_system() { show $SUDO pacman -Syu --noconfirm; }
        install_packages() {
            local packages=(fcitx5-mozc noto-fonts-cjk exfat-utils wget ffmpeg ruby python python-pip)
            show $SUDO pacman -S --noconfirm "${packages[@]}"
        }
    elif available zypper; then
        PM="zypper"
        update_system() { show $SUDO zypper refresh && show $SUDO zypper update -y; }
        install_packages() {
            local packages=(glibc-locale fcitx-mozc noto-sans-cjk-jp-fonts exfat-utils wget ffmpeg ruby python3 python3-pip)
            show $SUDO zypper install -y "${packages[@]}"
        }
    else
        error "サポートされていないパッケージマネージャです。"
    fi
    echo "パッケージマネージャ '$PM' を検出し、処理を準備しました。"
}

setup_localization() {
    local use_systemd=false
    if [ -d /run/systemd/system ]; then use_systemd=true; fi

    step "タイムゾーンを設定"
    if [ "$PM" = "apt" ]; then
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
             echo "Ubuntuではインストーラによって設定済みの可能性が高いため、対話的設定はスキップします（必要なら手動実行してください）。"
        else
             echo "Debian系を検出しました。対話的にタイムゾーンを設定します..."
             show $SUDO dpkg-reconfigure tzdata
        fi
    elif [ "$use_systemd" = true ] && available timedatectl; then
        echo "systemd環境を検出。タイムゾーンを Asia/Tokyo に設定します。"
        show $SUDO timedatectl set-timezone Asia/Tokyo
    else
        if [ -f /usr/share/zoneinfo/Asia/Tokyo ]; then
            show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
        fi
    fi

    step "ロケールを日本語に設定"
    if [ "$PM" = "apt" ]; then
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
             echo "Ubuntuでは設定済みの可能性が高いため、対話的設定はスキップします。"
        else
             echo "Debian系を検出しました。対話的にロケールを設定します..."
             show $SUDO dpkg-reconfigure locales
        fi
    elif [ "$use_systemd" = true ] && available localectl; then
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        echo "LANG=ja_JP.UTF-8" | show $SUDO tee /etc/locale.conf > /dev/null
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
    
    setup_localization

    step "Braveブラウザのインストール"
    local brave_installer
    brave_installer=$(mktemp)
    trap 'rm -f "$brave_installer"' EXIT
    # curlが入っていない環境も考慮しwgetを使用
    if available wget; then
        show wget https://dl.brave.com/install.sh -O "$brave_installer"
        show $SUDO sh "$brave_installer"
    else
        echo "wgetが見つかりません。Braveのインストールをスキップします。"
    fi
    rm -f "$brave_installer"
    trap - EXIT

    step "yt-dlpのインストール"
    if available wget; then
        show $SUDO wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
        show $SUDO chmod a+rx /usr/local/bin/yt-dlp
    fi

    step "Narou.rbのインストール"
    show $SUDO gem install narou

    step "Narou.rbの互換性設定（tilt バージョン調整）"
    show $SUDO gem install tilt -v 2.4.0
    show $SUDO gem uninstall tilt -v 2.6.1 || true

    step "Narou.rbの設定ファイル（yaml）を配置"
    
    local config_src_dir="$HOME/linux-startP"
    
    # --- Rubyパスの動的取得ロジック ---
    echo "Narou.rbのインストール先を検索しています..."
    
    # 1. RubyのGemベースディレクトリを取得 (例: /var/lib/gems/3.1.0)
    local gem_base_dir
    if ! gem_base_dir=$(ruby -e 'print Gem.dir' 2>/dev/null); then
        error "RubyのGemディレクトリが取得できませんでした。Rubyが正しくインストールされていない可能性があります。"
    fi

    # 2. narouのgemディレクトリを検索 (バージョン番号に依存しないようにワイルドカードで検索)
    # 想定: $gem_base_dir/gems/narou-x.x.x/webnovel/
    local target_dir
    # findで見つかった最初のnarouディレクトリを採用
    local narou_gem_path
    narou_gem_path=$(find "$gem_base_dir/gems" -maxdepth 1 -type d -name "narou-*" | sort -V | tail -n 1)

    if [ -z "$narou_gem_path" ]; then
        echo "警告: Narou.rbのGemディレクトリが見つかりませんでした。インストールに失敗している可能性があります。"
        target_dir=""
    else
        target_dir="${narou_gem_path}/webnovel/"
        echo "Narou.rbのターゲットディレクトリを特定: $target_dir"
    fi
    # -----------------------------------

    if [ ! -d "$config_src_dir" ]; then
        echo "警告: 設定ファイル元ディレクトリ $config_src_dir が見つかりません。yamlファイルのコピーをスキップします。"
    elif [ -z "$target_dir" ] || [ ! -d "$target_dir" ]; then
        echo "警告: コピー先ディレクトリ $target_dir が存在しません。スキップします。"
    else
        # ファイルコピー処理
        if [ -f "$config_src_dir/novel18.syosetu.com.yaml" ]; then
            show $SUDO cp "$config_src_dir/novel18.syosetu.com.yaml" "$target_dir"
            echo "novel18.syosetu.com.yaml をコピーしました。"
        fi
        
        if [ -f "$config_src_dir/ncode.syosetu.com.yaml" ]; then
            show $SUDO cp "$config_src_dir/ncode.syosetu.com.yaml" "$target_dir"
            echo "ncode.syosetu.com.yaml をコピーしました。"
        fi
    fi

    echo -e "\n---- セットアップが完了しました ----"
}

main "$@"
