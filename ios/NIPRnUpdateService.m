//
//  NIPRnUpdateService.m
//

#import "NIPRnUpdateService.h"
#import <AFNetworking/AFHTTPSessionManager.h>
#import <ZipArchive/ZipArchive.h>
#import "DiffMatchPatch.h"
#import "NIPRnHotReloadHelper.h"

#define ZIP @"zip"

@interface NIPRnUpdateService ()

@property (nonatomic, strong) AFHTTPSessionManager *httpSession;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
/**
 *  离线资源下载的路径
 */
@property (nonatomic, strong) NSString *downLoadPath;

/**
 *  用来记录本地数据的版本号，默认为@"0"
 */
@property (nonatomic, strong) NSString *localDataVersion;

/**
 *  用来记录本地数据的SDK版本号,默认=RN_SDK_VERSION
 */
@property (nonatomic, strong) NSString *localSDKVersion;

/**
 *  用来记录远程数据的版本号，默认为@"0"
 */
@property (nonatomic, strong) NSString *remoteDataVersion;

/**
 *  用来记录远程数据的SDK版本号,默认=RN_SDK_VERSION
 */
@property (nonatomic, strong) NSString *remoteSDKVersion;
/**
 *  用来验证文件的MD5值
 */
@property (nonatomic, strong) NSString *remoteMD5;

@end

@implementation NIPRnUpdateService
/**
 获取单例
 */
+ (instancetype)sharedService {
    static NIPRnUpdateService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NIPRnUpdateService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.httpSession = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
        self.httpSession.requestSerializer.timeoutInterval = 20;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        self.downLoadPath = [paths objectAtIndex:0];
    }
    return self;
}

/**
 *  初始化本地请求数据
 */
- (void)readLocalDataVersion {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id localDataInfo = [defaults objectForKey:RN_DATA_VERSION];
    if (localDataInfo) {
        self.localDataVersion = localDataInfo;
    } else {
        self.localDataVersion = NIP_RN_DATA_VERSION;
    }

    id localSDKInfo = [defaults objectForKey:RN_SDK_VERSION];
    if (localSDKInfo) {
        self.localSDKVersion = localSDKInfo;
        if (![self.localSDKVersion isEqualToString:NIP_RN_SDK_VERSION]) {
            self.localDataVersion = @"0";
            self.localSDKVersion = NIP_RN_SDK_VERSION;
        }
    } else {
        self.localSDKVersion = NIP_RN_SDK_VERSION;
    }
}

/**
 *  后台静默下载资源包
 */
- (void)requestRCTAssetsBehind:(NSString *)reLoadBundleName {
    self.reLoadBundleName = reLoadBundleName;
    [self readLocalDataVersion];
    [self performSelectorInBackground:@selector(requestRCTConfig) withObject:nil];
}

/**
 *  下载远程配置文件
 */
- (void)requestRCTConfig {
    __weak __typeof(self) weakSelf = self;
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/config?version=%@", [NIPRnManager sharedManager].bundleUrl, self.localDataVersion]];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [self.downloadTask cancel];
    self.downloadTask = [_httpSession downloadTaskWithRequest:request
        progress:nil
        destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
        }
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            if (error) {
                if ([weakSelf.delegate respondsToSelector:@selector(failedHandlerWithStatus:)]) {
                    [weakSelf.delegate failedHandlerWithStatus:NIPReadConfigFailed];
                }
            } else {
                NSString *actualPath = [filePath absoluteString];
                if ([actualPath hasPrefix:@"file://"]) {
                    actualPath = [actualPath substringFromIndex:7];
                }
                [weakSelf readConfigFile:actualPath];
            }
        }];
    [self.downloadTask resume];
}

/**
 *  读取配置文件
 */
- (void)readConfigFile:(NSString *)configFilePath {
    NSString *content = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"%@", content);
    NSArray *array = [content componentsSeparatedByString:@","];
    [[NSFileManager defaultManager] removeItemAtPath:configFilePath error:nil];

    BOOL needDownload = NO;
    for (NSString *line in array) {
        NSArray *items = [line componentsSeparatedByString:@"_"];
        NSString *remoteLowDataVersion = nil;
        BOOL isALL = false;
        NSString *incrementType = nil; //nil 全量包 否则非全量包
        if (items.count >= 4) {
            self.remoteSDKVersion = [items objectAtIndex:0];
            self.remoteDataVersion = [items objectAtIndex:1];
            //config文件分为2种形式，区分增量包或是全两包，两个字段是否存在
            if (items.count == 3) {
                //1.0_1_md5格式,全量包格式
                isALL = true;
                self.remoteMD5 = [items objectAtIndex:2];
                incrementType = @"1";
            } else {
                //1.0_1_0_0|1_md5增量包格式
                isALL = false;
                remoteLowDataVersion = [items objectAtIndex:2];
                incrementType = [items objectAtIndex:3];
                self.remoteMD5 = [items objectAtIndex:4];
            }

            if ([self.remoteSDKVersion isEqualToString:NIP_RN_SDK_VERSION]) {
                if ([self.localDataVersion isEqualToString:remoteLowDataVersion]) {
                    [self downLoadRCTZip:@"rn" withWholeString:incrementType];
                    needDownload = YES;
                    break;
                }
            }
        }
    }

    if (!needDownload) {
        NSString *zipPath = nil;
        if ((zipPath = [self filePathOfRnZip])) {
            [self alertIfUpdateRnZipWithFilePath:zipPath];
        } else {
            if ([self.delegate respondsToSelector:@selector(successHandlerWithFilePath:)]) {
                [self.delegate successHandlerWithFilePath:zipPath];
            }
        }
    }
}

/**
 *  执行请求并下载数据
 */
- (void)downLoadRCTZip:(NSString *)zipName withWholeString:(NSString *)incrementType {
    __weak __typeof(self) weakSelf = self;
    NSURL *URL;
    if ([incrementType intValue] == 1) {
        URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/all/%@/%@_%@_%@.zip?version=%@&sdk=%@",
                                                              [NIPRnManager sharedManager].bundleUrl,
                                                              self.remoteSDKVersion,
                                                              zipName,
                                                              self.remoteSDKVersion,
                                                              self.remoteDataVersion,
                                                              self.localDataVersion,
                                                              self.localSDKVersion]];
    } else {
        URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/increment/%@/%@_%@_%@_%@_%@.zip?version=%@&sdk=%@",
                                                              [NIPRnManager sharedManager].bundleUrl,
                                                              self.remoteSDKVersion,
                                                              zipName,
                                                              self.remoteSDKVersion,
                                                              self.remoteDataVersion,
                                                              self.localDataVersion,
                                                              incrementType,
                                                              self.localDataVersion,
                                                              self.localSDKVersion]];
    }
    NSLog(@"%@", URL);

    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [self.downloadTask cancel];
    self.downloadTask = [_httpSession downloadTaskWithRequest:request
        progress:nil
        destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
        }
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            if (error) {
                if ([weakSelf.delegate respondsToSelector:@selector(failedHandlerWithStatus:)]) {
                    [weakSelf.delegate failedHandlerWithStatus:NIPDownloadBundleFailed];
                }
            } else {
                NSString *actualPath = [filePath absoluteString];
                if ([actualPath hasPrefix:@"file://"]) {
                    actualPath = [actualPath substringFromIndex:7];
                }
                NSLog(@"热更新zip地址：%@", actualPath);
                //检查MD5值是否正确
                if (![weakSelf checkMD5OfRnZip:actualPath]) {
                    if ([weakSelf.delegate respondsToSelector:@selector(failedHandlerWithStatus:)]) {
                        [weakSelf.delegate failedHandlerWithStatus:NIPMD5CheckFailed];
                    }
                }
            }
        }];
    [self.downloadTask resume];
}

- (BOOL)checkMD5OfRnZip:(NSString *)path {

    NSString *MD5OfZip = [NIPRnHotReloadHelper getFileMD5WithPath:path];
    NSLog(@"下载文件的MD5值为：%@", MD5OfZip);
    //对于没有md5的情况直接返回成功
    if (!self.remoteMD5 || [self.remoteMD5 isEqualToString:MD5OfZip]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.remoteDataVersion forKey:RN_DATA_VERSION];
        [[NSUserDefaults standardUserDefaults] setObject:NIP_RN_SDK_VERSION forKey:RN_SDK_VERSION];
        [self alertIfUpdateRnZipWithFilePath:path];
        return true;
    }
    return false;
}

- (NSString *)filePathOfRnZip {
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [dirPaths objectAtIndex:0];
    NSArray *docmentZipNames = [NIPRnHotReloadHelper fileNameListOfType:ZIP fromDirPath:documentPath];
    if (hotreload_notEmptyArray(docmentZipNames)) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSString *path = [[documentsDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", docmentZipNames[0]]] absoluteString];
        if ([path hasPrefix:@"file://"]) {
            path = [path substringFromIndex:7];
        }
        return path;
    }
    return nil;
}

- (void)unzipBundle:(NSString *)filePath {
    if (filePath) {
        [self unzipAssets:filePath];
    }
}

- (void)alertIfUpdateRnZipWithFilePath:(NSString *)filePath {
    if ([self.delegate respondsToSelector:@selector(successHandlerWithFilePath:)]) {
        [self.delegate successHandlerWithFilePath:filePath];
    } else {
        [self unzipAssets:filePath];
        NIPRnController *controller = [[NIPRnManager sharedManager] loadControllerWithModel:self.reLoadBundleName];
        [[UIApplication sharedApplication].keyWindow setRootViewController:(UIViewController *) controller];
    }
}

/**
 *  删除老的客户端的rn资源相关文件
 */
- (void)removeOldDataFiles {
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    NSString *assetsDir = [[NSString alloc] initWithString:[docsDir stringByAppendingPathComponent:@"/assets"]];
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:assetsDir]) {
        [fileManager removeItemAtPath:assetsDir error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    }
}

- (void)unzipAssets:(NSString *)filePath {
    ZipArchive *miniZip = [[ZipArchive alloc] init];
    if ([miniZip UnzipOpenFile:filePath]) {
        BOOL ret = [miniZip UnzipFileTo:self.downLoadPath overWrite:YES];
        if (YES == ret) {
            NSLog(@"download ok==");
            [NIPRnHotReloadHelper registerIconFontsByNames:[[NIPRnManager sharedManager] fontNames]];
        }
        [miniZip UnzipCloseFile];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }

    [self checkAndApplyIncrement];
    [self checkAndApplyAssetsConfig];
    [[NIPRnManager sharedManager] loadBundleUnderDocument];
}

- (void)checkAndApplyIncrement {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [docPaths objectAtIndex:0];
    NSArray *docmentBundleNames = [NIPRnHotReloadHelper fileNameListOfType:JSBUNDLE fromDirPath:documentPath];
    NSString *mainBundleText = nil;
    NSString *increBundleText = nil;
    NSString *mainBundlePath = nil;
    NSString *increBundlePath = nil;
    BOOL hasIncrement = NO;
    for (NSString *bundleName in docmentBundleNames) {
        NSString *jsBundlePath = [[NSString alloc] initWithString:[documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.%@", bundleName, JSBUNDLE]]];
        if ([bundleName isEqualToString:@"index"]) {
            mainBundlePath = jsBundlePath;
            mainBundleText = [NSString stringWithContentsOfFile:jsBundlePath encoding:NSUTF8StringEncoding error:nil];
        }
        if ([bundleName isEqualToString:@"increment"]) {
            increBundlePath = jsBundlePath;
            increBundleText = [NSString stringWithContentsOfFile:jsBundlePath encoding:NSUTF8StringEncoding error:nil];
            hasIncrement = YES;
        }
    }
    if (hasIncrement) {
        DiffMatchPatch *patch = [[DiffMatchPatch alloc] init];
        NSError *error = nil;
        NSMutableArray *patches = [patch patch_fromText:increBundleText error:&error];
        if (!error) {
            NSArray *result = [patch patch_apply:patches toString:mainBundleText];
            NSString *content = result[0];
            if (result.count) {
                NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
                BOOL success = [fileManager createFileAtPath:mainBundlePath contents:data attributes:nil];
                if (success) {
                    [fileManager removeItemAtPath:increBundlePath error:NULL];
                }
            }
        }
    }
}

- (void)checkAndApplyAssetsConfig {
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [docPaths objectAtIndex:0];
    NSString *configFilePath = [documentPath stringByAppendingPathComponent:@"assetsConfig.txt"];
    NSString *content = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *array = [content componentsSeparatedByString:@","];
    [[NSFileManager defaultManager] removeItemAtPath:configFilePath error:nil];
    NSString *tempPath = nil;
    for (NSString *path in array) {
        if (path.length) {
            tempPath = [documentPath stringByAppendingPathComponent:path];
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
        }
    }
}

@end

