//
//  NIPRnController.h
//  NSIP
//  Created by 王翔 on 16/2/23.
//  Copyright © 2017年 netease. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RCTNavigator;
@class RCTRootView;

@interface NIPRnController : UIViewController

//  根据业务指定的bundle，加载对应的module
- (id)initWithBundleName:(NSString *)bundleName moduleName:(NSString *)moduleName;

//  加载Bundle时候使用的loading图片
@property(nonatomic, copy) UIImage *loadingImage;

//  rn的根视图
@property(nonatomic, strong) RCTRootView *rctRootView;

//  业务请求时可能需要的参数
@property(nonatomic, copy, readwrite) NSDictionary *appProperties;

// rn内嵌的导航条视图
@property(nonatomic, strong) RCTNavigator *navigator;

@end
