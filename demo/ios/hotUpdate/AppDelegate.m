/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AppDelegate.h"

#import <React/RCTAssert.h>
#import <NIPRnManager.h>
#import <NIPRnController.h>
#import <NIPRnUpdateService.h>

#define MODULE_NAME @"hotUpdate"
#define BUNDLE_SERVER @"https://raw.githubusercontent.com/fegos/fego-rn-update/master/demo/increment/ios/increment"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    //  初始化rn相关
    [[NIPRnManager sharedManager] preInitBundle];
    [NIPRnManager sharedManager].fontNames = @[ @"iconfont" ];
    __weak __typeof(self) weakSelf = self;
    RCTSetFatalHandler(^(NSError *err) {
        NSLog(@"%@", err);
        [[NIPRnManager sharedManager] useDefaultRnAssets];
        [[NIPRnManager sharedManager] loadBundleUnderDocument];
        [weakSelf resetKeyController];
    });

    // 初始化窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self resetKeyController];
    [self.window makeKeyAndVisible];

    // 启动后进行后台热更新
    [self doHotReload];

    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self doHotReload];
}

//  设置根controller
- (void)resetKeyController {
    NIPRnController *controller = [[NIPRnController alloc] initWithBundleName:@"index" moduleName:MODULE_NAME];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
    self.window.rootViewController = controller;
#pragma clang diagnostic pop
}

- (void)doHotReload {
    __weak __typeof(self) weakSelf = self;
    [NIPRnUpdateService sharedService].requestUrl = BUNDLE_SERVER;
    [[NIPRnUpdateService sharedService] requestRCTAssetsBehind:^{
        [weakSelf resetKeyController];
    }
                                                          fail:^{

                                                          }];
}

@end
