//
//  DNKWiFiViewController.h
//  DNKLANIoT_Example
//
//  Created by 陈群 on 2023/3/13.
//  Copyright © 2023 cqcool. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DNKPhilipsIoT/DNKPhilipsIoT.h>
NS_ASSUME_NONNULL_BEGIN

@interface DNKWiFiViewController : UIViewController
@property (nonatomic, weak) DNKPhilipsIoT *ioT;
@end

NS_ASSUME_NONNULL_END
