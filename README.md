# DNKPhilipsIoTDemo

绑定网关演示Demo,支持有线绑定和无限绑定两种方式。

## 1.有线绑定方式
  ### 网关设备网口连接网线后，可直接调用服务端接口绑定网关。

## 2.无线绑定方式 
### 网关设备网口未连接网线时，会发射AP热点，手机安装APP后需连接该热点，在APP里输入要连接的网络名称和密码，可调用setWiFiWithEssid设置Wi-Fi，设置成功后，调用服务端接口绑定网关。
  > -(void)setWiFiWithEssid: (NSString *)essid psk: (NSString *)psk resultBlock: (IoTBoo LResult)resultBlock;
  
* 注意:
    1. 使用无线绑定方式，需向苹果申请组播权限。 若无改权限，控制台会输出
    Error Domain=NSPOSIXErrorDomain Code=65 "No route to host" UserInfo={NSLocalizedDescription=No route to host, NSLocalizedFailureReason=Error in send() function.} 
    详情可参考 https://blog.51cto.com/u_15318120/6024139
    2. 使用无线绑定方式，当Wi-Fi账号或密码不对，网关在尝试连接Wi-Fi，连接不上时会重新发射AP热点。
    3. 使用无线绑定方式，在解绑网关时，需重置网关Wi-Fi信息,否则网关不会再发射热点。可调用 
  > -(void)resetWiFf iMithResultBlock: (IoTBoolResult)resultBlock;
