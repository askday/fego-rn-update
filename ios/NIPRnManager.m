//
//  NIPRnManager.m
//  NSIP
//  Created by wx on 16/2/23.
//  Copyright © 2017年 netease. All rights reserved.
//

#if __has_include(<React/RCTAssert.h>)
#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#else
#import "RCTBridge.h"
#import "RCTBundleURLProvider.h"
#endif

#import "NIPRnDefines.h"
#import "NIPRnManager.h"
#import "NIPRnHotReloadHelper.h"

@interface NIPRnManager ()

/**
 *  根据bundle业务名称存储对应的bundle
 */
@property (nonatomic, strong) NSMutableDictionary *bundleDic;

@end

@implementation NIPRnManager

/**
 获取单例
 */
+ (instancetype)sharedManager {
    static dispatch_once_t predicate;
    static NIPRnManager *manager = nil;
    dispatch_once(&predicate, ^{
        manager = [[NIPRnManager alloc] init];
    });
    return manager;
}

- (id)init {
    if (self = [super init]) {
        self.bundleDic = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark 根据业务获取bundle
/**
 *  获取当前app内存在的所有bundle
 *  首先获取位于docment沙河目录下的jsbundle文件
 *  然后获取位于app保内的jsbundle文件
 *  将文件的路径放在一个字典里，如果有重复以document优先
 */
- (void)preInitBundle {
    NSArray *bundleNames = [self getAllBundles];
    for (NSString *bundelName in bundleNames) {
        NSURL *bundelPath = [self getJsLocationPath:bundelName];
        RCTBridge *bridge = [[RCTBridge alloc] initWithBundleURL:bundelPath
                                                  moduleProvider:nil
                                                   launchOptions:nil];
        [self.bundleDic setObject:bridge forKey:bundelName];
    }
#if DEBUG
    NSString *defaultBundleName = @"index";
    NSURL *bundelPath = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:defaultBundleName fallbackResource:defaultBundleName];
    RCTBridge *bridge = [[RCTBridge alloc] initWithBundleURL:bundelPath
                                              moduleProvider:nil
                                               launchOptions:nil];
    [self.bundleDic setObject:bridge forKey:defaultBundleName];
#endif
}

/**
 oc与js联通的桥，在manager初始化的时候就生成
 @param bundleName bundleName
 @return RCTBridge
 */
- (RCTBridge *)getBridgeByBundleName:(NSString *)bundleName {
    return [self.bundleDic objectForKey:bundleName];
}

/**
 热更新完成后，加载存放在Document目录下的被更新的bundle文件
 */
- (void)loadBundleUnderDocument {
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [dirPaths objectAtIndex:0];

    NSArray *tmplist = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentPath error:nil];
    NSRange range;
    range.location = 0;
    NSInteger typeLength = [JSBUNDLE length] + 1;
    for (NSString *filename in tmplist) {
        if ([[filename pathExtension] isEqualToString:JSBUNDLE]) {
            range.length = filename.length - typeLength;
            NSString *nameWithoutExtension = [filename substringWithRange:range];

            NSURL *bundelPath = [self getJsLocationPath:nameWithoutExtension];
            RCTBridge *bridge = [[RCTBridge alloc] initWithBundleURL:bundelPath
                                                      moduleProvider:nil
                                                       launchOptions:nil];
            [self.bundleDic setObject:bridge forKey:nameWithoutExtension];
        }
    }
}

#pragma mark 目录处理
/**
 获取所有bundle
 @return bundle数组
 */
- (NSArray *)getAllBundles {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    //  如果APP升级则需要将app自带的bundle资源拷贝到Document目录，便于以后管理
    id appVersion = [defaults objectForKey:KEY_APP_VERSION];
    if (!appVersion || ![appVersion isEqualToString:APP_VERSION]) {
        [self useDefaultRnAssets];
    } else {
        //  如果APP版本相同，但是Build不同也需要将app自带的bundle资源拷贝到Document目录，便于以后管理
        id appBuildVersion = [defaults objectForKey:KEY_APP_BUILD_VERSION];
        if (!appBuildVersion || ![appBuildVersion isEqualToString:APP_BUILD]) {
            [self useDefaultRnAssets];
        }
    }

    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [dirPaths objectAtIndex:0];
    NSArray *docmentBundleNames = [NIPRnHotReloadHelper fileNameListOfType:JSBUNDLE fromDirPath:documentPath];
    return docmentBundleNames;
}

- (void)useDefaultRnAssets {
    [self copyRnToLocal];
    [[NSUserDefaults standardUserDefaults] setObject:LOCAL_BUNDLE_VERSION forKey:KEY_BUNDLE_VERSION];
    [[NSUserDefaults standardUserDefaults] setObject:APP_VERSION forKey:KEY_APP_VERSION];
    [[NSUserDefaults standardUserDefaults] setObject:APP_BUILD forKey:KEY_APP_BUILD_VERSION];
}

/// 缓存RN包到本地
- (void)copyRnToLocal {
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *document = [docPaths objectAtIndex:0];

    NSString *bundlePath = [document stringByAppendingPathComponent:@"index.jsbundle"];
    [NIPRnHotReloadHelper copyFile:[[NSBundle mainBundle] pathForResource:@"index" ofType:@"jsbundle"] toPath:bundlePath];

    NSString *assetsPath = [document stringByAppendingPathComponent:@"assets"];
    [NIPRnHotReloadHelper copyFolderFrom:[[NSBundle mainBundle] pathForResource:@"assets" ofType:nil] to:assetsPath];
}

#pragma mark 工具
- (NSURL *)getJsLocationPath:(NSString *)bundleName {
    NSURL *jsCodeLocation = nil;

    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    NSString *bundelFullName = [NSString stringWithFormat:@"/%@.%@", bundleName, JSBUNDLE];
    NSString *jsBundlePath = [[NSString alloc] initWithString:[docsDir stringByAppendingPathComponent:bundelFullName]];
    jsCodeLocation = [NSURL URLWithString:jsBundlePath];

    return jsCodeLocation;
}

#pragma mark js bridge
RCT_EXPORT_MODULE()

@end
