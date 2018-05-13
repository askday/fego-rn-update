const fs = require('fs');
const crypto = require('crypto');

module.exports = {
  /**
   * 读取文件内容
   * @param {*} src 文件源
   */
  readFile(src) {
    const promise = new Promise(((resolve, reject) => {
      fs.readFile(src, 'utf-8', (err, data) => {
        if (!err && data) {
          console.log(`读取文件success${src}`);
          resolve(data);
        } else {
          console.log(`读取文件failure${src}${err}`);
          reject(err);
        }
      });
    }));
    return promise;
  },

  /**
     * 删除目录及下边的所有文件、文件夹
     */
  deleteFolder(dirPath) {
    let files = [];
    if (fs.existsSync(dirPath)) {
      files = fs.readdirSync(dirPath);
      files.forEach((file) => {
        const curPath = `${dirPath}/${file}`;
        if (fs.statSync(curPath).isDirectory()) { // recurse
          this.deleteFolder(curPath);
        } else { // delete file
          fs.unlinkSync(curPath);
        }
      });
      fs.rmdirSync(dirPath);
    }
  },

  /**
   * 生成文件md5值
   * @param {*} filepath
   */
  generateFileMd5(filepath) {
    const buffer = fs.readFileSync(filepath);
    const fsHash = crypto.createHash('md5');
    fsHash.update(buffer);
    const md5 = fsHash.digest('hex');
    return md5;
  },
};
