src=~/WorkSpace/fego/fego-rn-update/
dest=`pwd`
rsync -rv --exclude=.git package.json sync.sh node_modules build Pods $src $dest
