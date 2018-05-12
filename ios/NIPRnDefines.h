//
//  NIPRnDefines.h
//  Created by 王翔 on 16/2/23.
//  Copyright © 2017年 netease. All rights reserved.
//

#define JSBUNDLE @"jsbundle"

#pragma mark - APP Info

#define APP_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]
#define KEY_APP_VERSION @"KEY_APP_VERSION"

#define APP_BUILD [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
#define KEY_APP_BUILD_VERSION @"KEY_APP_BUILD_VERSION"

#pragma mark - RN Define

// 每次发新版建议 1.若远程有对应RN包，则与远端RN包版本号同步 2.若远端尚无对应这个app版本的RN包，则此值归0 (不修改也不会出现问题)
#define LOCAL_BUNDLE_VERSION @"0"
#define KEY_BUNDLE_VERSION @"KEY_BUNDLE_VERSION"

#pragma mark - nil & null & class
#define hotreload_notEmptyString(tempString) ([tempString isKindOfClass:[NSString class]] && tempString.length && !([tempString compare:@"null" options:NSCaseInsensitiveSearch] == NSOrderedSame))
#define hotreload_notEmptyArray(tempArray) ([tempArray isKindOfClass:[NSArray class]] && tempArray.count > 0)

// --忽略未定义方法警告
#define HOTRELOAD_SUPPRESS_Undeclaredselector_WARNING(Stuff)              \
do                                                                    \
{                                                                     \
_Pragma("clang diagnostic push")                                  \
_Pragma("clang diagnostic ignored \"-Wundeclared-selector\"") \
Stuff;                                                    \
_Pragma("clang diagnostic pop")                                   \
} while (0)
