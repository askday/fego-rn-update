# 在终端中执行脚本 sh pack.sh platform
platform=$1
path=$2
sdkVer=$3
#临时变量记录当前rn资源数据对应sdk的版本号
newVer=1
#生成的最终rn zip包的名称
zipName=''
#rn资源ftp的相对路径
allBundleDirPath=$path/$platform/all/$sdkVer/
if [ ! -e "$allBundleDirPath" ]; then
	mkdir -p $allBundleDirPath
fi

#增量包资源路径
incrementDir=$path/$platform/increment/
if [ ! -e "$incrementDir" ]; then
	mkdir -p $incrementDir
fi
#临时解压包资源路径
tmpDir=$path/$platform/tmp/
if [ ! -e "$tmpDir" ]; then
	mkdir -p $tmpDir
fi
#config文件路径
allBundleConfigFilePath=$allBundleDirPath"config"

# 判断是否是新一期版本第一次开发,是则生成config文件
isInitStatus=0
if [ ! -e "$allBundleConfigFilePath" ]; then
	echo "0">$allBundleConfigFilePath
else
	 isInitStatus=1
fi

#读取config文件的内容，确认当前应该生成的最新版本号
for line in  `cat $allBundleConfigFilePath`
do
    newVer=${line}
done

# 如果不是第一次打包，且config中版本号为0时，需要改为1（之后不需要改是因为如果做过增量生成之后config就是下一次的最新版本号）
if [ $isInitStatus = 1 ];then
	if [ $newVer = 0 ];then
		newVer=1
	fi
fi
#压缩包的名字
zipName="rn_"$sdkVer"_"$newVer".zip"

#删除deploy目录下的所有文件
deploy=`pwd`/deploy
echo $deploy
rm -rf $deploy
mkdir $deploy
#rn资源打包
cd ../
react-native bundle --entry-file index.js --platform $platform --dev false --bundle-output $deploy/index.jsbundle --assets-dest $deploy

#拷贝字体文件到打包文件夹中
cp -rf app/icon/*.ttf $deploy/

#生成压缩包放于deploy下
cd $deploy
zip -r $zipName *
cd ../
#将资源包拷贝到指定目录下
cp deploy/$zipName $allBundleDirPath
