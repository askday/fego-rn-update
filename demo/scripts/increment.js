/**
 * 增量包生成脚本入口文件
 */
const fs = require('fs');
const zipper = require('zip-local');
const jsbundle = require('./incre/jsbundle');
const Util = require('./incre/util');

/** ****************** 变量说明 ****************** */
const argv = process.argv;
//  平台
const platform = argv[2];
const destPath = argv[3];
// sdk版本
const sdkVer = argv[4];

// 最新版本号
let newVer = 0;
// 包路径前缀
const pathPrefix = destPath + platform;
// 增量包路径
const incrementPathPrefix = `${pathPrefix}/increment/`;
// 全量包路径
const allPathPrefix = `${pathPrefix}/all/`;
//  临时解压包路径
const tmpPathPrefix = `${pathPrefix}/tmp/`;

/** ****** 生成步骤 ******************
 * 1、首先解压未解压的所有需要比较的包
 */
function unzipAll() {
  // 看增量config是否存在，如果存在，则删除
  const incrementConfigPath = `${incrementPathPrefix}/config`;
  if (fs.existsSync(incrementConfigPath)) {
    fs.unlinkSync(incrementConfigPath);
  }

  // 看全量包中是否有包存在（打包脚本在第一次使用时会自动生成config文件，如果没有该文件，说明没有包存在）
  const allConfigPath = `${allPathPrefix + sdkVer}/config`;
  console.log('===============');
  console.log(allConfigPath)
  console.log('===============');
  if (!fs.existsSync(allConfigPath)) {
    console.log('还没有可用的包，请先生成包');
    newVer = 0;
    return;
  }

  // 读取全量包中config文件，获取最新版本号
  const allConfigFileContent = fs.readFileSync(allConfigPath);
  console.log(`allConfigFileContent:${allConfigFileContent}`);
  newVer = Number.parseInt(allConfigFileContent, 10);
  if (newVer === 0) {
    // 如果取到的值为0，则说明这是首次生成增量包，需要将最新版本更改为1
    newVer = 1;
  }

  // 从最新包开始依次解压包
  for (let i = newVer; i >= 0; i--) {
    const zipName = `rn_${sdkVer}_${i}`;
    const allZipFilePath = `${allPathPrefix + sdkVer}/${zipName}.zip`;
    const allUnzipDirPath = `${tmpPathPrefix}/${zipName}`;
    // 兼容只存在老包就执行增量更新的情况，判断是否存在新包，不存在就终止整个脚本运行
    if (!fs.existsSync(allZipFilePath)) {
      console.log(`新包${zipName}.zip不存在`);
      continue;
    }
    // 判断是否已经存在sdkVer目录，不存在则创建，以免出现文件夹不存在的问题
    if (fs.existsSync(allUnzipDirPath)) {
      Util.deleteFolder(allUnzipDirPath);
    }
    fs.mkdirSync(allUnzipDirPath);
    // 解压包
    zipper.sync.unzip(allZipFilePath).save(allUnzipDirPath);
  }

  // 更新config文件，将其改为newVer+1
  fs.writeFileSync(allConfigPath, `${newVer + 1}`);
}

/**
 * 2、开始生成包，其中包括增量包生成、压缩
 * @param {*} platform 平台，android/ios
 */
function generateIncrement() {
  for (let i = newVer - 1; i >= 0; i--) {
    jsbundle(i, newVer, sdkVer, platform, destPath);
  }
}

function deletezipAll() {
  Util.deleteFolder(tmpPathPrefix);
}

// 1、首先解压未解压的所有需要比较的包
unzipAll();
// 2、开始生成包，其中包括增量包生成、压缩
generateIncrement();
// 3、删除临时解压文件
// deletezipAll();
