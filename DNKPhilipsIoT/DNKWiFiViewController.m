//
//  DNKWiFiViewController.m
//  DNKLANIoT_Example
//
//  Created by 陈群 on 2023/3/13.
//  Copyright © 2023 cqcool. All rights reserved.
//

#import "DNKWiFiViewController.h"

@interface DNKWiFiViewController ()
@property (weak, nonatomic) IBOutlet UILabel *oneLabel;
@property (weak, nonatomic) IBOutlet UITextField *nameView;
@property (weak, nonatomic) IBOutlet UITextField *passwordView;
/// 网关热点WiFi
@property (copy, nonatomic) NSString *gatewayHotWiFi;
@end

@implementation DNKWiFiViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *tips = [NSString stringWithFormat:@"请将手机Wi-Fi连接到设备热点：%@，密码与WiFi名一致,连接成功后返回小狄管家APP。\n\n\n注意：由于苹果设备连接Wi-Fi能力有限，若尝试多次后仍无法连接Wi-Fi，请尝试点击热点：%@右侧的“ⓘ”按钮，点击“忽略此网络”，尝试重新连接。", self.ioT.apName, self.ioT.apName];
    self.oneLabel.text = tips;
    self.nameView.text = @"";
    self.passwordView.text = @"";
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}
- (IBAction)bindGatewayByWiFi:(id)sender {
    [self.ioT setWiFiWithEssid:self.nameView.text psk:self.passwordView.text resultBlock:^(BOOL result, NSError * _Nullable error) {
        NSLog(@"%@", result ? @"Wi-Fi设置成功" : @"Wi-Fi设置失败");
        /*
         网络上设置成功后，网关海鸥
         */
    }];
}
- (IBAction)backAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
