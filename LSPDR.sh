#!/bin/bash
#
# このスクリプトは、Linuxデスクトップ環境に日本語環境と便利なツールをセットアップします。
# Debian/Ubuntu, Fedora/RHEL, Arch Linux ベースのシステムをサポートします。
#

# スクリプトの堅牢性を高める設定
# -e: コマンドが失敗したら即座に終了する
# -u: 未定義の変数を参照したらエラーとする
# -o pipefail: パイプラインの途中でコマンドが失敗した場合もエラーとする
set -euo pipefail

# --- グローバル変数 ---
# スクリプトの実行に必要な権限を管理
SUDO=""

# --- ユーティリティ関数 ---

# コマンドの存在を確認する
available() {
    command -v "$1" >/dev/null 2>&1
}

# 実行するコマンドを画面に表示してから実行する
show() {
    echo "+ $*"
    "$@"
}

# エラーメッセージを表示して終了する
error() {
    echo "エラー: $1" >&2
    exit 1
}

# 各ステップのヘッダーを表示する
step() {
    echo -e "\n---- $1 ----"
}

# --- メイン処理関数 ---

# OS情報を表示する
show_os_info() {
    step "現在のOS情報"
    if [ -f /etc/os-release ]; then
        # /etc/os-release を読み込んで表示
        . /etc/os-release
        echo "オペレーティングシステム: ${NAME:-不明}"
        echo "バージョン: ${VERSION:-不明}"
    else
        # uname コマンドでフォールバック
        echo "オペレーティングシステム: $(uname -s)"
        echo "カーネルバージョン: $(uname -r)"
    fi
}

# パッケージマネージャと、それに応じたコマンド、パッケージリストを設定する
setup_distro_specifics() {
    step "パッケージマネージャとディストリビューション固有の設定を確認"

    local pm
    if available apt-get; then
        pm="apt"
        SUDO_INSTALL="$SUDO apt-get install -y"
        SUDO_UPDATE="$SUDO apt-get update && $SUDO apt-get upgrade -y"
        # Debian/Ubuntu向けのパッケージリスト
        PACKAGES=(
            locales
            fcitx-mozc
            task-japanese-desktop # 日本語フォントや関連ツールをまとめて導入
            exfat-fuse
            wget
            ffmpeg
            ruby-full
            python3
            python3-pip
        )
    elif available dnf; then
        pm="dnf"
        SUDO_INSTALL="$SUDO dnf install -y"
        SUDO_UPDATE="$SUDO dnf upgrade -y"
        # Fedora/RHEL向けのパッケージリスト
        PACKAGES=(
            glibc-langpack-ja # ロケール用
            fcitx5-mozc # fcitx5が主流
            google-noto-cjk-fonts # 日本語フォント
            exfat-utils
            wget
            ffmpeg
            ruby
            python3
            python3-pip
        )
    elif available yum; then
        pm="yum"
        SUDO_INSTALL="$SUDO yum install -y"
        SUDO_UPDATE="$SUDO yum update -y"
        # CentOS/RHEL (旧) 向けのパッケージリスト
        PACKAGES=(
            # yumではパッケージ名が異なる場合がある
            langpacks-ja
            fcitx-mozc
            vlgothic-p-fonts # 日本語フォントの例
            exfat-utils
            wget
            ffmpeg # EPELリポジトリが必要な場合が多い
            ruby
            python3
            python3-pip
        )
    elif available pacman; then
        pm="pacman"
        SUDO_INSTALL="$SUDO pacman -S --noconfirm"
        SUDO_UPDATE="$SUDO pacman -Syu --noconfirm"
        # Arch Linux向けのパッケージリスト
        PACKAGES=(
            # Archではロケールは手動設定が基本
            fcitx5-mozc
            noto-fonts-cjk
            exfat-utils
            wget
            ffmpeg
            ruby
            python
            python-pip
        )
    elif available zypper; then
        pm="zypper"
        SUDO_INSTALL="$SUDO zypper install -y"
        SUDO_UPDATE="$SUDO zypper refresh && $SUDO zypper update -y"
        # openSUSE向けのパッケージリスト
        PACKAGES=(
            glibc-locale
            fcitx-mozc
            noto-sans-cjk-jp-fonts
            exfat-utils
            wget
            ffmpeg
            ruby
            python3
            python3-pip
        )
    else
        error "サポートされていないパッケージマネージャです。apt, dnf, yum, pacman, zypper のいずれかが必要です。"
    fi
    echo "パッケージマネージャ '$pm' を検出しました。"
    # グローバル変数に設定をエクスポート
    export SUDO_INSTALL SUDO_UPDATE PACKAGES pm
}


# タイムゾーンとロケールを設定する
setup_localization() {
    step "タイムゾーンを Asia/Tokyo に設定"
    if available timedatectl; then
        show $SUDO timedatectl set-timezone Asia/Tokyo
    else
        echo "timedatectlコマンドが見つかりません。手動での設定を試みます。"
        show $SUDO ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
    fi

    step "ロケールを日本語に設定"
    if [ "$pm" = "apt" ]; then
        # Debian/Ubuntu固有のロケール設定
        show $SUDO locale-gen ja_JP.UTF-8
        show $SUDO update-locale LANG=ja_JP.UTF-8
    elif available localectl; then
        show $SUDO localectl set-locale LANG=ja_JP.UTF-8
    else
        echo "localectlコマンドが見つかりません。ロケール設定をスキップします。"
        echo "手動で /etc/locale.conf などを編集してください。"
    fi
}

main() {
    # rootで実行されているか確認し、必要に応じてSUDO変数を設定
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
        echo "このスクリプトはシステムの変更を行うため、sudoパスワードの入力が必要になる場合があります。"
    fi

    show_os_info
    setup_distro_specifics

    step "システムのアップデート"
    show $SUDO_UPDATE

    setup_localization

    step "必要なパッケージのインストール"
    # shellcheck disable=SC2086 # 変数展開を意図的に行っている
    show $SUDO_INSTALL "${PACKAGES[@]}"

    step "Braveブラウザのインストール"
    # 一時ファイルにダウンロードして実行し、後始末する
    local brave_installer
    brave_installer=$(mktemp)
    show wget https://dl.brave.com/install.sh -O "$brave_installer"
    show $SUDO sh "$brave_installer"
    rm "$brave_installer"

    step "yt-dlpのインストール"
    show $SUDO wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
    show $SUDO chmod a+rx /usr/local/bin/yt-dlp

    step "Narou.rbのインストール"
    show $SUDO gem install narou

    echo -e "\n---- セットアップが完了しました ----"
    echo "出力内容にエラーがないか確認してください。"
    echo "日本語入力やフォントを有効にするには、システムの再起動が必要な場合があります。"
}

# スクリプトの実行開始
main
