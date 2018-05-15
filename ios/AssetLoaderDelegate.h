//
//  AssetLoaderDelegate.h
//  RCTVideo
//
//  Created by Kranthi Kumar on 14/05/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import AVKit;

@interface AssetLoaderDelegate : NSObject <AVAssetResourceLoaderDelegate>
- (void)setCustomData:(NSString*)customData;
@end
