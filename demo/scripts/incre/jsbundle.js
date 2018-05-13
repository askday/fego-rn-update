/**
 * bundle增量生成
 */
const fs = require('fs');
const zipper = require('zip-local');
const assets = require('./assets');
const Util = require('./util');

const diff = require('../third/diff_match_patch_uncompressed');
const rd = require('../third/file_list');

const dmp = new diff.diff_match_patch();

/**
 * bundle增量生成函数
 * @param {*} oldVer bundle老版本号
 * @param {*} newVer bundle新版本号
 * @param {*} sdkVer sdk版本号
 * @param {*} platform 平台，android/ios
 */
function JsBundle(oldVer, newVer, sdkVer, platform, destPath) {
  // 旧包内容
  let bunOld = '';
  // 新包内容
  let bunNew = '';
  // 获取的增量内容
  let patchText = '';

  // 包路径前缀
  const pathPrefix = destPath + platform;
  // 增量包路径前缀；
  const incrementPathPrefix = `${pathPrefix}/increment/`;
  // 全量包路径前缀：
  const allPathPrefix = `${pathPrefix}/tmp/`;
  // 全量包bundle的名字
  const bundleName = 'index.jsbundle';
  // 增量包里bundle的名字
  const incrementBundleName = 'increment.jsbundle';
  // 全量包zip名字
  const zipName = `rn_${sdkVer}_${newVer}`;
  // 是否是增量包，'0'表示是增量包，'1'表示全量包
  let isIncrement = '0';
  // 增量包zip名字
  let incrementName = `rn_${sdkVer}_${newVer}_${oldVer}_${isIncrement}`;

  /**
   * 做差量分析，并生成差量包
   */
  function diffLaunch() {
    const promise = new Promise(((resolve, reject) => {
      // 生成增量内容
      const text1 = bunOld;
      const text2 = bunNew;
      const diff = dmp.diff_main(text1, text2, true);
      if (diff.length > 2) {
        dmp.diff_cleanupSemantic(diff);
      }
      const patchList = dmp.patch_make(text1, text2, diff);
      patchText = dmp.patch_toText(patchList);

      // 比对增量和新包大小，以防改动较多导致增量包比全量还大的问题
      if (patchText.length > text2.length) {
        isIncrement = '1';
      } else {
        isIncrement = '0';
      }

      // 生成到的指定路径如果不存在，则一一生成指定目录
      incrementName = `rn_${sdkVer}_${newVer}_${oldVer}_${isIncrement}`;
      let path = `${sdkVer}/${incrementName}/${incrementBundleName}`;
      path = path.split('/');
      let sumPath = incrementPathPrefix;
      for (let i = 0; i < path.length - 1; i++) {
        if (!fs.existsSync(sumPath + path[i])) {
          fs.mkdirSync(sumPath + path[i]);
        }
        sumPath = `${sumPath + path[i]}/`;
      }

      // 将生成的增量内容存储到指定路径下的bundle文件中
      const text = isIncrement === '0' ? patchText : text2;
      const finalName = isIncrement === '0' ? incrementBundleName : bundleName;
      fs.writeFile(`${incrementPathPrefix + sdkVer}/${incrementName}/${finalName}`, text, (err) => {
        if (err) {
          console.log(`生成增量包failure${err}`);
          reject(err);
        } else {
          console.log(`生成增量包${platform}_${newVer}_${oldVer}_success`);
          resolve(isIncrement);
        }
      });
    }));
    return promise;
  }

  /**
   * 合并成最新的全量包（可选）
   */
  function patchLaunch() {
    const promise = new Promise(((resolve, reject) => {
      const text1 = bunOld;
      const patches = dmp.patch_fromText(patchText);

      // var ms_start = (new Date).getTime();
      const results = dmp.patch_apply(patches, text1);
      // var ms_end = (new Date).getTime();
      // console.log(ms_end - ms_start);

      let error = false;
      const patchResults = results[1];
      for (let x = 0; x < patchResults.length; x++) {
        if (!patchResults[x]) {
          error = true;
        }
      }
      if (error) {
        console.log('增量更新failure');
        reject('增量更新failure');
      }
      fs.writeFile(`${incrementPathPrefix + sdkVer}/${incrementName}/all.bundle`, results[0], (err) => {
        if (err) {
          console.log(`增量更新failure${err}`);
          reject(err);
        } else {
          console.log('增量更新success');
          resolve(patchText);
        }
      });
    }));
    return promise;
  }

  /**
   * 在bundle和assets均生成增量后进行压缩，并更新config文件
   */
  function zipIncrement() {
    const zipPath = `${incrementPathPrefix + sdkVer}/${incrementName}`;
    zipper.zip(zipPath, (error, zipped) => {
      if (!error) {
        zipped.save(`${zipPath}.zip`, (error) => {
          if (!error) {
            const md5Value = Util.generateFileMd5(`${zipPath}.zip`);
            console.log('ZIP EXCELLENT!');
            Util.deleteFolder(zipPath);
            fs.appendFileSync(`${incrementPathPrefix}/config`, `${sdkVer}_${newVer}_${oldVer}_${isIncrement}_${md5Value},`);
            console.log(`${pathPrefix}===============`);
            fs.writeFileSync(`${pathPrefix}/config`, fs.readFileSync(`${incrementPathPrefix}config`));
          } else {
            console.log('ZIP FAIL!');
          }
        });
      }
    });
  }

  // 读取新旧版本的bundle文件内容
  const promises = [oldVer, newVer].map(
    id => Util.readFile(`${allPathPrefix}rn_${sdkVer}_${id}/${bundleName}`),
  );

  Promise.all(promises).then((posts) => {
    bunOld = posts[0].toString();
    bunNew = posts[1].toString();
    // 1、生成bundle增量
    return diffLaunch();
  }).then((value) => {
    // return patchLaunch();
    // 2、生成图片资源的增量
    const fileList = rd.readFileSync(`${allPathPrefix}/${zipName}`);
    for (let i = 0; i < fileList.length; i++) {
      if (fileList[i].search('.ttf') !== -1) {
        const tmp = fileList[i].split('/');
        const name = tmp[tmp.length - 1];
        fs.writeFileSync(`${incrementPathPrefix + sdkVer}/${incrementName}/${name}`, fs.readFileSync(fileList[i]));
      }
    }
    console.log('=========================');
    console.log(oldVer);
    console.log(newVer);
    console.log(sdkVer);
    console.log(platform);
    console.log(value);
    console.log(destPath);
    assets(oldVer, newVer, sdkVer, platform, value, destPath);
    console.log('=========================');

    // 3、将生成的增量包进行压缩操作，并删除之前生成的文件夹即其下的所有内容
    zipIncrement();
    return true;
  }, (err) => {
    console.log(err);
  });
}

module.exports = JsBundle;
