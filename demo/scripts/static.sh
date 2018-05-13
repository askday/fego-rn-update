#!/bin/bash
dest=~/WorkSpace/game/luckyshop-app/a.txt
rm -rf $dest
touch $dest
function ergodic(){
    for file in ` ls $1 `
    do
        if [ -d $1"/"$file ]
        then
             ergodic $1"/"$file  $2
        else
			 filename=$1/$file
			 if [ "${filename##*.}" = "$2" ]; then
			 	echo $filename
			 	cat   "$1/$file" >> $dest
             fi
        fi
    done
}
#生成lua代码
#===================
# rm -rf $dest
# touch $dest
# ergodic './src/game' 'lua'
# #删除空行
# cat $dest | sed -e '/^$/d'> b.txt
# #删除注释行
# cat b.txt | sed -e '/\/\//d' -e '/--/d' -e '/@param/d' -e '/@return/d' -e '/]]/d'> lua.txt
# rm -rf b.txt
#===================
#生成java代码
#===================
rm -rf $dest
touch $dest
# ergodic '../android/app/src' 'java'
ergodic '../node_modules/fego-update' 'java'
#删除空行
cat $dest | sed -e '/^$/d'> b.txt
#删除注释行
cat b.txt | sed -e '/\/\//d' -e '/^\t$/d' -e '/^ $/d' -e '/^[ \t]*$/d' -e '/--/d' -e '/@param/d' -e '/@return/d' -e '/]]/d'> java.txt
rm -rf b.txt
#===================

# #生成oc代码
# #===================
# rm -rf $dest
# touch $dest
# ergodic '../ios' 'm'
# #删除空行
# cat $dest | sed -e '/^$/d'> b.txt
# #删除注释行
# cat b.txt | sed -e '/\/\//d' -e '/--/d' -e '/@param/d' -e '/@return/d' -e '/]]/d'> oc.txt
# rm -rf b.txt
# #===================
# #生成c++代码
