/*
 *   热更新网络请求服务类
 */

#import <UIKit/UIKit.h>
#import "NIPRnDefines.h"
#import "NIPRnManager.h"

//资源下载成功回调
typedef void (^UpdateAssetsSuccesBlock)(void);
typedef void (^UpdateAssetsFailBlock)(void);

@interface NIPRnUpdateService : NSObject

+ (instancetype)sharedService;

@property (nonatomic, strong) NSString *requestConfigUrl;
@property (nonatomic, strong) NSString *requestUrl;

- (void)requestRCTAssetsBehind:(UpdateAssetsSuccesBlock)success fail:(UpdateAssetsFailBlock)fail;

@end
