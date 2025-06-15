#!/bin/sh
set -eu

# ユーティリティ関数
available() { command -v "$1" >/dev/null; }
show() { (set -x; "$@"); }

main() {
    # スクリプトの実行ユーザーを確認
    case "$(whoami)" in
        root) sudo="";;
        *) sudo="$(first_of sudo doas run0 pkexec sudo-rs)" || show "Please install sudo/doas/run0/pkexec/sudo-rs to proceed.";;
    esac

    # Linux システムのアップデート
    show $sudo apt update && $sudo apt upgrade -y

    # システム設定
    show cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
    show $sudo apt install -y task-japanese locales-all 
    show $sudo localectl set-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP.UTF-8"
    source /etc/default/locale
    show $sudo apt install -y fcitx-mozc
    show $sudo apt install -y task-japanese-desktop
    show $sudo apt install -y exfat-fuse
    show $sudo ln -s /usr/sbin/mount.exfat-fuse /sbin/mount.exfat
    show wget https://dl.brave.com/install.sh && $sudo sh install.sh

    # yt-dlp インストール
    show $sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
    show $sudo chmod a+rx /usr/local/bin/yt-dlp
    show $sudo mv ${HOME}/linux-startP/yt-dlp.conf /usr/local/bin/
    show $sudo ln /usr/local/bin/yt-dlp.conf ${HOME}/yt-dlp.link
    show $sudo apt-get install -y ffmpeg
    show cd /usr/local/src/
    show $sudo wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
    show $sudo tar jxfv phantomjs-2.1.1-linux-x86_64.tar.bz2
    show $sudo cp -pr phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/bin/
    show export OPENSSL_CONF=/etc/ssl/

    # Ruby & Narou.rb インストール
    show $sudo apt install -y ruby-full
    show $sudo gem install narou
    show wget -P /var/lib/gems/3.1.0/gems/narou-3.9.1/webnovel/ https://github.com/whiteleaf7/narou/blob/304aea554f918b6104225aa27a21febcc7fd19e7/webnovel/ncode.syosetu.com.yaml
    show wget -P /var/lib/gems/3.1.0/gems/narou-3.9.1/webnovel/ https://github.com/whiteleaf7/narou/blob/304aea554f918b6104225aa27a21febcc7fd19e7/webnovel/novel18.syosetu.com.yaml
    show $sudo gem install tilt -v 2.4.0
    show $sudo gem uninstall tilt -v 2.6.0

    # 再アップデート
    show $sudo apt update && $sudo apt upgrade -y

    # 依存関係のインストール
    show $sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev
    
    # rbenv のインストール
    show curl -sL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-installer | bash -
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    source ~/.bashrc
    show rbenv install 3.3.4
    show rbenv global 3.3.4

    # Python のインストール
    show $sudo apt-get install python -y
    show $sudo apt-get install python3 -y
    show $sudo apt-get install python3-distutils -y
    show $sudo apt-get install python3-pip -y
    export PATH=$PATH:~/.local/bin
    show $sudo apt update && $sudo apt upgrade -y
}

main
