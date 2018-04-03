//
//

#import <UIKit/UIKit.h>
#import "NIPRnDefines.h"
#import "NIPRnManager.h"

/**
 资源下载回调
 */
typedef void (^CFRCTUpdateAssetsSuccesBlock)(void);
typedef void (^CFRCTUpdateAssetsFailBlock)(void);

@interface NIPRnUpdateService : NSObject

+ (instancetype)sharedService;

@property(nonatomic, strong) NSString *requestUrl;
@property(nonatomic, strong) NSString *reLoadBundleName;
@property(nonatomic, weak) id<NIPRnManagerDelegate> delegate;

- (void)unzipBundle:(NSString *)filePath;
- (void)requestRCTAssetsBehind:(NSString *)reLoadBundleName;

@end
