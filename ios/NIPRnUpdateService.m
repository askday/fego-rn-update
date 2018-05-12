//
//  NIPRnUpdateService.m
//
#import <AFNetworking/AFHTTPSessionManager.h>
#import <ZipArchive/ZipArchive.h>

#import "NIPRnUpdateService.h"
#import "NIPRnHotReloadHelper.h"
#import "DiffMatchPatch.h"

#define ZIP @"zip"

@interface NIPRnUpdateService ()

@property (nonatomic, copy) UpdateAssetsSuccesBlock successBlock;
@property (nonatomic, copy) UpdateAssetsFailBlock failBlock;

@property (nonatomic, strong) AFHTTPSessionManager *httpSession;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
/**
 *  离线资源下载的路径
 */
@property (nonatomic, strong) NSString *downLoadPath;

/**
 *  用来记录本地数据的版本号，默认为@"0"
 */
@property (nonatomic, strong) NSString *localVersion;

/**
 *  用来记录本地数据的SDK版本号,默认=KEY_APP_VERSION
 */
@property (nonatomic, strong) NSString *sdkVersion;

/**
 *  用来记录远程数据的版本号，默认为@"0"
 */
@property (nonatomic, strong) NSString *remoteVersion;

/**
 *  用来记录远程包的类型0-增量包 1-全量包
 */
@property (nonatomic, strong) NSString *remoteZipType;

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
 *  后台静默下载资源包
 */
- (void)requestRCTAssetsBehind:(UpdateAssetsSuccesBlock)success fail:(UpdateAssetsFailBlock)fail {
    [self readLocalInfo];
    self.successBlock = success;
    self.failBlock = fail;
    [self performSelectorInBackground:@selector(requestRCTConfig) withObject:nil];
}

- (void)updateResult:(id)isSuccess {
    if ([isSuccess boolValue]) {
        if (self.successBlock) {
            self.successBlock();
        }
    } else {
        if (self.failBlock) {
            self.failBlock();
        }
    }
}

/**
 *  初始化本地请求数据
 */
- (void)readLocalInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id localBundleVersion = [defaults objectForKey:KEY_BUNDLE_VERSION];
    if (localBundleVersion) {
        self.localVersion = localBundleVersion;
    } else {
        self.localVersion = LOCAL_BUNDLE_VERSION;
    }

    id localSDKInfo = [defaults objectForKey:KEY_APP_VERSION];
    if (localSDKInfo) {
        self.sdkVersion = localSDKInfo;
        if (![self.sdkVersion isEqualToString:APP_VERSION]) {
            self.localVersion = @"0";
            self.sdkVersion = APP_VERSION;
        }
    } else {
        self.sdkVersion = APP_VERSION;
    }
}

/**
 *  下载远程配置文件
 */
- (void)requestRCTConfig {
    __weak __typeof(self) weakSelf = self;

    NSURL *URL = nil;
    if (self.requestConfigUrl) {
        URL = [NSURL URLWithString:self.requestConfigUrl];
    } else {
        URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/config?version=%@", self.requestUrl, self.localVersion]];
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [self.downloadTask cancel];
    self.downloadTask = [_httpSession downloadTaskWithRequest:request
        progress:nil
        destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];

            // 设置时间戳时间，避免出现错误
            NSDate *newDate = [NSDate date];
            long int timeSp = (long) [newDate timeIntervalSince1970];
            NSString *tempTime = [NSString stringWithFormat:@"%ld", timeSp];
            return [documentsDirectoryURL URLByAppendingPathComponent:tempTime];
        }
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            if (error) {
                if (self.failBlock) {
                    self.failBlock();
                }
            } else {
                NSString *actualPath = [filePath absoluteString];
                if ([actualPath hasPrefix:@"file://"]) {
                    actualPath = [actualPath substringFromIndex:7];
                }
                [weakSelf performSelectorInBackground:@selector(readConfigFile:) withObject:actualPath];
            }
        }];
    [self.downloadTask resume];
}

/**
 *  读取配置文件
 */
- (void)readConfigFile:(NSString *)configFilePath {
    NSString *content = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"%@", configFilePath);
    NSLog(@"%@", content);
    if (self.requestConfigUrl) {
        //  如果是通过接口访问，需要解析data数据
        NSData *responseData = [content dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:nil];
        if ([[response objectForKey:@"retcode"] intValue] == 100) {
            content = [response objectForKey:@"data"];
        }
    }

    //读取完毕后需要删除下载的文件，否则会造成文件读取老的记录
    [[NSFileManager defaultManager] removeItemAtPath:configFilePath error:nil];

    if (!content)
        return;

    NSArray *array = [content componentsSeparatedByString:@","];
    BOOL needDownload = NO;
    for (NSString *line in array) {
        NSArray *items = [line componentsSeparatedByString:@"_"];

        //  线上最新包针对本地宝的版本号，如线上是5-4，那么本地是4的时候下载更新
        NSString *remoteIncrentmentVersion = nil;
        if (items.count >= 4) {
            NSString *remoteSDKVersion = [items objectAtIndex:0];
            self.remoteVersion = [items objectAtIndex:1];
            //1.0.0_1_0_0|1_md5增量包格式
            remoteIncrentmentVersion = [items objectAtIndex:2];
            self.remoteZipType = [items objectAtIndex:3];
            self.remoteMD5 = [items objectAtIndex:4];

            if ([remoteSDKVersion isEqualToString:APP_VERSION]) {
                if ([self.localVersion isEqualToString:remoteIncrentmentVersion]) {
                    [self downLoadZip];
                    needDownload = YES;
                    break;
                }
            }
        }
    }
}

/**
 *  执行请求并下载数据
 */
- (void)downLoadZip {
    __weak __typeof(self) weakSelf = self;
    NSURL *URL;
    if (self.remoteZipType.intValue == 0) {
        URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/increment/%@/%@_%@.zip",
                                                              self.requestUrl,
                                                              self.sdkVersion,
                                                              self.remoteVersion,
                                                              self.localVersion]];
    } else {
        URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/increment/%@/%@.zip",
                                                              self.requestUrl,
                                                              self.sdkVersion,
                                                              self.remoteVersion]];
    }
    NSLog(@"%@", URL);

    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [self.downloadTask cancel];
    self.downloadTask = [_httpSession downloadTaskWithRequest:request
        progress:nil
        destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            // 设置时间戳时间，避免出现错误
            NSDate *newDate = [NSDate date];
            long int timeSp = (long) [newDate timeIntervalSince1970];
            NSString *tempTime = [NSString stringWithFormat:@"%ld", timeSp];
            return [documentsDirectoryURL URLByAppendingPathComponent:tempTime];
        }
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            if (error) {
                if (self.failBlock) {
                    self.failBlock();
                }
            } else {
                NSString *actualPath = [filePath absoluteString];
                if ([actualPath hasPrefix:@"file://"]) {
                    actualPath = [actualPath substringFromIndex:7];
                }
                NSLog(@"热更新zip地址：%@", actualPath);
                [weakSelf performSelectorInBackground:@selector(checkMD5OfRnZip:) withObject:actualPath];
            }
        }];
    [self.downloadTask resume];
}

- (void)checkMD5OfRnZip:(NSString *)path {
    NSString *MD5OfZip = [NIPRnHotReloadHelper getFileMD5WithPath:path];
    NSLog(@"下载文件的MD5值为：%@", MD5OfZip);
    if ([self.remoteMD5 isEqualToString:MD5OfZip]) {
        [self unzipAssets:path];

        [[NSUserDefaults standardUserDefaults] setObject:self.remoteVersion forKey:KEY_BUNDLE_VERSION];
        [[NSUserDefaults standardUserDefaults] setObject:APP_VERSION forKey:KEY_APP_VERSION];
        [self performSelectorOnMainThread:@selector(updateResult:) withObject:@YES waitUntilDone:NO];
    } else {
        [self performSelectorOnMainThread:@selector(updateResult:) withObject:@NO waitUntilDone:NO];
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
    BOOL unzipOK = NO;
    ZipArchive *miniZip = [[ZipArchive alloc] init];
    if ([miniZip UnzipOpenFile:filePath]) {
        unzipOK = [miniZip UnzipFileTo:self.downLoadPath overWrite:YES];
        if (YES == unzipOK) {
            NSLog(@"unzip ok==");
        }
        [miniZip UnzipCloseFile];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }

    if (unzipOK) {
        [NIPRnHotReloadHelper registerIconFontsByNames:[[NIPRnManager sharedManager] fontNames]];
        if ([self.remoteZipType intValue] == 0) {
            [self checkAndApplyIncrement];
            [self checkAndApplyAssetsConfig];
        }
        [[NIPRnManager sharedManager] loadBundleUnderDocument];
    }
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

