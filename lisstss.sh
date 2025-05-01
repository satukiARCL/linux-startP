find ~/novels/ -type f -name "*.txt" -exec cp {} ~/Documents/ \;
find ~/novels/ -not -name '*.ini' -not -name '*.txt' -not -name '*.rb' -not -name '*.yaml' -not -name '*.yaml.backup' -not -name '*.jpg' -not -name '*.png' -not -name '*.gif' -type f -exec cp {} ~/Documents/LAEGO/ \;
cd ~/Documents/LAEGO/
rename -v 's/^([^.]+)$/$1.txt/' *
find ~/Documents/ -type f -name "*.txt" -exec nkf -sc --overwrite {} \;
