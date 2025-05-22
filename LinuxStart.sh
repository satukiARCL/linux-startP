#!/bin/sh
set -eu
main() {
    case "$(whoami)" in
        root) sudo="";;
        *) sudo="$(first_of sudo doas run0 pkexec sudo-rs)" || error "Please install sudo/doas/run0/pkexec/sudo-rs to proceed.";;
    esac
        #Linux_System_Update
    show $sudo apt update && $sudo apt upgrade -y

#System_Setting
show cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
show $sudo apt install -y task-japanese locales-all 
show $sudo localectl set-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP.UTF-8"
source /etc/default/locale
show $sudo apt install -y fcitx-mozc
show $sudo apt install -y task-japanese-desktop
show $sudo apt install -y exfat-fuse
show $sudo ln -s /usr/sbin/mount.exfat-fuse /sbin/mount.exfat
show wget https://dl.brave.com/install.sh && $sudo sh install.sh

#Yt-dlp_Install
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
"""
show $sudo touch /usr/local/bin/yt-dlp.conf
"""

#Ruby_&&_Narou.rb_Install
show $sudo apt install -y ruby-full
show $sudo gem install narou
show wget -P /var/lib/gems/3.1.0/gems/narou-3.9.1/webnovel/ https://github.com/whiteleaf7/narou/blob/304aea554f918b6104225aa27a21febcc7fd19e7/webnovel/ncode.syosetu.com.yaml
show wget -P /var/lib/gems/3.1.0/gems/narou-3.9.1/webnovel/ https://github.com/whiteleaf7/narou/blob/304aea554f918b6104225aa27a21febcc7fd19e7/webnovel/novel18.syosetu.com.yaml
show $sudo gem install tilt -v 2.4.0
show $sudo gem uninstall tilt -v 2.6.0
#re-update
show $sudo apt update && sudo apt upgrade -y
"""
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev
curl -sL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-installer | bash -
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
rbenv install 3.3.4
rbenv global 3.3.4
cd ~/
"""
"""
#Python_install
sudo apt-get install python -y
sudo apt-get install python3 -y
sudo apt-get install python3-distutils -y
sudo apt-get install python3-pip -y
cd ~
ls ~/.local/bin
export PATH=$PATH:~/.local/bin
sudo apt update && sudo apt upgrade -y
"""
}
