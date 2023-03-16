//
//  DNKIoTLink.h
//  DNKPhilipsIoT
//
//  Created by 陈群 on 2023/3/10.
//

#import <Foundation/Foundation.h>
#import "DNKIoTConfig.h"
NS_ASSUME_NONNULL_BEGIN
typedef void (^IoTBoolResult)(BOOL result, NSError * _Nullable error);
@interface DNKPhilipsIoT : NSObject
/// 网关热点名称
@property (nonatomic, strong, readonly) NSString *apName;
- (instancetype)initWithConfig:(DNKIoTConfig *)config;
 
/// 连接网关热点绑定网关
/// - Parameters:
///   - essid: 要连接的Wi-Fi名称
///   - psk: Wi-Fi 密码
///   - resultBlock: 绑定结果
- (void)setWiFiWithEssid:(NSString *)essid psk:(NSString *)psk resultBlock:(IoTBoolResult)resultBlock;
/// 通过 Wi-Fi绑定网关后，网关不会再开启热点，只有重置后，才能再通过Wi-Fi绑定网关
- (void)resetWiFiWithResultBlock:(IoTBoolResult)resultBlock;
/// 关闭IoT
- (void)destroy;
@end

NS_ASSUME_NONNULL_END
