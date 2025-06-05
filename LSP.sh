#!/bin/bash
set -e

# 必要なアプリ一覧（LinuxStart.shから抜粋）
APPS=(
    task-japanese
    locales-all
    task-japanese-desktop
    ruby-full
    ffmpeg
    build-essential
    git
    curl
    wget
    vim
    gnome-tweaks
    gparted
    vlc
    firefox
    chromium-browser
    code
    exfat-fuse
    exfat-utils
    unzip
    htop
    net-tools
)

echo "==== パッケージリストを更新 ===="
sudo apt update

echo "==== 必要なアプリをインストール ===="
sudo apt install -y "${APPS[@]}"

echo "==== exFATマウント用シンボリックリンク作成 ===="
if [ ! -e /sbin/mount.exfat ]; then
    sudo ln -s /usr/sbin/mount.exfat-fuse /sbin/mount.exfat
fi

echo "==== Google Chrome をインストール ===="
wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y /tmp/google-chrome.deb
rm /tmp/google-chrome.deb

echo "==== Braveブラウザをインストール ===="
sudo wget https://dl.brave.com/install.sh -O /tmp/brave-install.sh
sudo bash /tmp/brave-install.sh

echo "==== yt-dlp をインストール ===="
sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

echo "==== Ruby gem: narou, tilt をインストール ===="
sudo gem install narou
sudo gem install tilt -v 2.4.0
sudo gem uninstall tilt -v 2.6.0 || true

echo "==== 完了しました ===="
