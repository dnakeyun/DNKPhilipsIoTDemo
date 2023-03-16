//
//  DNKIoTConfig.h
//  NewSmart
//
//  Created by 陈群 on 2022/4/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 mqtt长连接通道配置信息
 */
@interface DNKIoTConfig : NSObject
/// 网关UDID
@property (nonatomic, copy) NSString *udid;  

@end 
NS_ASSUME_NONNULL_END
