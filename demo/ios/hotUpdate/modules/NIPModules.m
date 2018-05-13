//
//  NIPModules.m
//  hotUpdate
//
//  Created by 赵松 on 2017/12/12.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import "NIPModules.h"
#import "AppDelegate.h"

@implementation NIPModules

RCT_EXPORT_MODULE(FegoRnUpdate)

RCT_EXPORT_METHOD(hotReload) {
    AppDelegate *appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    [appDelegate doHotReload];
}

@end
