//
//  QRScanViewController.h
//  系统二维码扫描
//
//  Created by long on 17/4/29.
//  Copyright © 2017年 long. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QRScanVC : UIViewController
@property (readonly, strong, nonatomic) UIView *navigationView;
@property (readonly, strong, nonatomic) UIView *lineView;
@property (readonly, strong, nonatomic) UIButton *backButton;
@property (readonly, strong, nonatomic) UILabel *navigationTitleLabel;

@property (nonatomic, copy) void(^scanResultBlock)(QRScanVC *currentVC, NSString *code);
- (void)startScanSession;
- (void)stopScanSession;
@end 
