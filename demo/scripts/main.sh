current=`pwd`
dest=$current/../../test/
sdkVer=1.0.0

sh all.sh android $dest $sdkVer
node increment.js android $dest $sdkVer

sh all.sh ios $dest $sdkVer
node increment.js ios $dest $sdkVer
