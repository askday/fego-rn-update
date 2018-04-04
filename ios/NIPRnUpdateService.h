//
//

#import <UIKit/UIKit.h>
#import "NIPRnDefines.h"
#import "NIPRnManager.h"


@interface NIPRnUpdateService : NSObject

+ (instancetype)sharedService;

@property(nonatomic, strong) NSString *requestConfigUrl;
@property(nonatomic, strong) NSString *requestUrl;
@property(nonatomic, strong) NSString *reLoadBundleName;
@property(nonatomic, weak) id<NIPRnManagerDelegate> delegate;

- (void)unzipBundle:(NSString *)filePath;
- (void)requestRCTAssetsBehind:(NSString *)reLoadBundleName;

@end
