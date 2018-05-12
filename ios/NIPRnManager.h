//
//  NIPRnManager.h
//  Created by wx on 16/2/23.
//  Copyright © 2017年 netease. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<React/RCTAssert.h>)
#import <React/RCTBridgeModule.h>
#else
#import "RCTBridgeModule.h"
#endif

@class NIPRnController;

@interface NIPRnManager : NSObject <RCTBridgeModule>
/**
 获取单例
 */
+ (instancetype)sharedManager;

/**
 预加载jsbundle数据
 */
- (void)preInitBundle;

/**
 oc与js联通的桥，在manager初始化的时候就生成
 @param bundleName bundleName
 @return RCTBridge
 */
- (RCTBridge *)getBridgeByBundleName:(NSString *)bundleName;

/*
热更新完成后，加载存放在Document目录下的被更新的bundle文件
*/
- (void)loadBundleUnderDocument;
- (void)useDefaultRnAssets;
/**
 字体名字
 */
@property(nonatomic, copy) NSArray *fontNames;

@end
