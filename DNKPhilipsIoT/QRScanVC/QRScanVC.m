//
//  QRScanViewController.m
//  系统二维码扫描
//
//  Created by long on 17/4/29.
//  Copyright © 2017年 long. All rights reserved.
//

#import "QRScanVC.h"
#import "DNKDevice.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
/// 根据颜色16进制值 + 透明度获取对应的UIColor 对象
/// - Parameters:
///   - hex: 颜色16进制值
///   - alpha: 透明度
static inline UIColor* hexAColor(NSInteger hex, CGFloat alpha) {
    CGFloat red = ((hex & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((hex & 0xFF00) >> 8) / 255.0;
    CGFloat blue = (hex & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}
/// 根据颜色16进制值 获取对应的UIColor 对象
/// - Parameter hex: 颜色16 进制值
static inline UIColor* hexColor(NSInteger hex) {
    return hexAColor(hex, 1);
}
@interface QRScanVC () <AVCaptureMetadataOutputObjectsDelegate, CAAnimationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate>
{
    AVCaptureSession *_session;//输入输出中间桥梁

    UIStatusBarStyle _orginalStyle;
    
    //提示将二维码放入框内label
    UILabel *_textLabel;
    
    //手电筒按钮
    UIButton *_torchBtn;
    //轻触照亮/关闭
    UILabel *_tipLabel;
    //光线第一次变暗
    BOOL _isFirstBecomeDark;
    
    float _lastBrightnessValue;
}
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *layer;
@property (strong, nonatomic) UIView *maskView;
@property (strong, nonatomic) UIImageView *scanLineView;
@property (strong, nonatomic) CABasicAnimation *lineAnimation;
/// 用于控制是否显示扫描，子类调用stopScanSession，就会关闭扫描，调用startScanSession就会开启
@property (assign, nonatomic) BOOL isRunningScan;

@end

@implementation QRScanVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _isFirstBecomeDark = YES;
    self.isRunningScan = YES; 
    [self initBaseUI];
    //初始化摄像头
    [self initScan];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.isRunningScan) {
        [self startScan];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isRunningScan) {
        [_session stopRunning];
        [self switchTorch:NO];
    }
}
- (void)dismissViewContrllerAimated:(BOOL)animated {
    [self stopScan];
    UIViewController *vc = [self.navigationController popViewControllerAnimated:animated];
    if (!vc) {
        [self dismissViewControllerAnimated:animated completion:nil];
    }
}
- (void)dismissViewContrller {
    [self dismissViewContrllerAimated:YES];
}
#pragma mark - public method

- (void)startScanSession {
    self.isRunningScan = YES;
    if (_scanLineView == nil) {
        [self.view addSubview:self.scanLineView];
    }
    [self startScan];
}
- (void)stopScanSession {
    self.isRunningScan = NO;
    [self stopScan];
    [_scanLineView removeFromSuperview];
}
- (void)setIsRunningScan:(BOOL)isRunningScan {
    if (_isRunningScan == isRunningScan) {
        return;
    }
    _isRunningScan = isRunningScan;
    if (isRunningScan) {
        [self registerApplicationNotification];
    } else {
        [self resignApplicationNotification];
    }
}
#pragma mark - notification
- (void)startScan {
    if (_session && !_session.isRunning) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self->_session startRunning];            
        });
    }
    [self.scanLineView.layer addAnimation:self.lineAnimation forKey:nil];
}
- (void)stopScan {
    if (_session && _session.isRunning) {
        [_session stopRunning];
    }
    [self.scanLineView.layer removeAllAnimations];
    self.lineAnimation = nil;
}

#pragma mark - 从相册解析二维码
- (void)openAlbum {
    // 1.判断相册是否可以打开
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    // 2. 创建图片选择控制器
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    /**
     typedef NS_ENUM(NSInteger, UIImagePickerControllerSourceType) {
     UIImagePickerControllerSourceTypePhotoLibrary, // 相册
     UIImagePickerControllerSourceTypeCamera, // 用相机拍摄获取
     UIImagePickerControllerSourceTypeSavedPhotosAlbum // 相簿
     }
     */
    // 3. 设置打开照片相册类型(显示所有相簿)
    ipc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    // ipc.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    // 照相机
    // ipc.sourceType = UIImagePickerControllerSourceTypeCamera;
    // 4.设置代理
    ipc.delegate = self;
    // 5.modal出这个控制器
    [ipc setModalPresentationStyle:UIModalPresentationFullScreen];
    [self presentViewController:ipc animated:YES completion:nil];
}
#pragma mark UIImagePickerControllerDelegate
// 获取图片后的操作
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    // 销毁控制器
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self switchTorch:NO];
    // 设置图片
    NSString *qrDataStr = [self stringValueFrom:info[UIImagePickerControllerOriginalImage]];
    [self handleQrCode:qrDataStr];
}
///系统识别相册二维码
- (NSString *)stringValueFrom:(UIImage *)image {
    ///系统识别二维码
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    // 取得识别结果
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    NSString *resultStr;
    if (features.count == 0) {
        return (@"照片中未识别到二维码");
    }
    for (int index = 0; index < [features count]; index ++) {
        CIQRCodeFeature *feature = [features objectAtIndex:index];
        resultStr = feature.messageString;
    }
    return resultStr;
}

#pragma mark - scan
- (BOOL)checkCameraAuthority {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    NSLog(@"status is:%ld", (long)status);
    if (status == AVAuthorizationStatusDenied) {
        [self alertControllerTitle:(@"请在设置->隐私中允许该软件访问摄像头") message:Nil cancelTitle:(@"取消") confirmTitle:(@"确定")];
        return NO;
    }
    if (status == AVAuthorizationStatusRestricted) {
        [self alertControllerTitle:(@"设备不支持") message:Nil cancelTitle:(@"取消") confirmTitle:(@"确定")];
        return NO;
    }
    if (![UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera]) {
        [self alertControllerTitle:(@"模拟器不支持该功能") message:Nil cancelTitle:(@"取消") confirmTitle:(@"确定")];
        return NO;
    }
    return YES;
}

- (void)initScan {
    if (![self checkCameraAuthority]) {
        return;
    }
    //获取摄像设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //创建输出流
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    //设置扫描有效区域
    /*
     1、这个CGRect参数和普通的Rect范围不太一样，它的四个值的范围都是0-1，表示比例。
     2、经过测试发现，这个参数里面的x对应的恰恰是距离左上角的垂直距离，y对应的是距离左上角的水平距离。
     3、宽度和高度设置的情况也是类似。
     3、举个例子如果我们想让扫描的处理区域是屏幕的下半部分，我们这样设置
     output.rectOfInterest = CGRectMake(0.5, 0, 0.5, 1);
     */
    output.rectOfInterest = CGRectMake(0.1, 0.2, 0.5, 0.5);
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    //设置光感代理输出
    AVCaptureVideoDataOutput *respondOutput = [[AVCaptureVideoDataOutput alloc] init];
    [respondOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    _session = [[AVCaptureSession alloc] init];
    //高质量采集率
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    if ([_session canAddInput:input]) [_session addInput:input];
    if ([_session canAddOutput:output]) [_session addOutput:output];
    if ([_session canAddOutput:respondOutput]) [_session addOutput:respondOutput];
    
    //设置扫码支持的编码格式
    output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    self.layer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    self.layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    self.layer.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.layer atIndex:0];
    if (_session && _session.isRunning) {
        [_session stopRunning];
    }
    //开始捕获
    [_session startRunning];
    
}
#pragma mark - CAAnimationDelegate
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat pathWidth = DNKDevice.screenWidth-100;
    CGFloat orginY = (DNKDevice.screenHeight-pathWidth)/2-50;
    //内部方框path
    CGPathAddRect(path, nil, CGRectMake(50, orginY, pathWidth, pathWidth));
    //外部大框path
    CGPathAddRect(path, nil, _maskView.bounds);
    //两个path取差集，即去除差集部分
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.path = path;
    self.maskView.layer.mask = maskLayer;
}
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
// 光感回调
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    // 该值在 -5~12 之间
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    if ((_lastBrightnessValue>0 && brightnessValue>0) ||
        (_lastBrightnessValue<=0 && brightnessValue<=0)) {
        return;
    }
    _lastBrightnessValue = brightnessValue;
    [self switchTorchBtnState:brightnessValue<=0];
}
#pragma mark - AVCaptureMetadataOutputObjectsDelegate
// 扫描结果回调
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.count > 0) {
        [self stopScan];
        AVMetadataMachineReadableCodeObject *metaDataObject = [metadataObjects objectAtIndex:0];
        [self switchTorch:NO];
        NSString *qrDataStr = metaDataObject.stringValue;
        NSLog(@"qrCode: %@", qrDataStr);
        [self handleQrCode:qrDataStr];
    }
}
- (void)handleQrCode:(NSString *)qrDataStr {
    [self dismissViewContrllerAimated:NO];
    if (self.scanResultBlock) {
        self.scanResultBlock(self, qrDataStr);
    }
}

- (void)switchTorchClick:(UIButton *)btn {
    [self switchTorch:!btn.isSelected];
}

- (void)switchTorch:(BOOL)on {
    //更换按钮状态
    _torchBtn.selected = on;
    _tipLabel.text = [NSString stringWithFormat:(@"轻触%@"), on?(@"关闭"):(@"照亮")];
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        if (on) {
            //调用led闪光灯
            [device lockForConfiguration:nil];
            [device setTorchMode: AVCaptureTorchModeOn];
        } else {
            //关闭闪光灯
            if (device.torchMode == AVCaptureTorchModeOn) {
                [device setTorchMode: AVCaptureTorchModeOff];
            }
        }
    }
}

- (void)switchTorchBtnState:(BOOL)show {
    _torchBtn.hidden = !show && !_torchBtn.isSelected;
    _tipLabel.hidden = !show && !_torchBtn.isSelected;
    _textLabel.hidden = show || _torchBtn.isSelected;
    if (show) {
        if (_isFirstBecomeDark) {
            CABasicAnimation *animate = [CABasicAnimation animationWithKeyPath:@"opacity"];
            animate.fromValue = @(1);
            animate.toValue = @(0);
            animate.duration = .6;
            animate.repeatCount = 2;
            [_torchBtn.layer addAnimation:animate forKey:nil];
            _isFirstBecomeDark = NO;
        }
    }
}
- (void)alertControllerTitle:(NSString *)title message:(NSString *)message cancelTitle:(NSString *)cancelTitle confirmTitle:(NSString *)confirmTitle {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    [self presentViewController:alertController animated:YES completion:^{
        
    }];
}
- (NSBundle *)sharedBundle {
    static NSBundle *scanBundle = nil;
    if (scanBundle == nil) {
        NSString *strResourcesBundle = [[NSBundle mainBundle] pathForResource:@"QRScan" ofType:@"bundle"];
        scanBundle = [NSBundle bundleWithPath:strResourcesBundle];
    }
    return scanBundle;
}
- (UIImage *)imageWithName:(NSString *)imageName {
    int scale = [UIScreen mainScreen].scale;
    NSString *scaleImgName = [imageName stringByAppendingFormat:@"@%dx", scale];
    // 找到对应images夹下的图片
    NSString *strC = [[self sharedBundle] pathForResource:imageName ofType:@"png" inDirectory:@"images"];
    if (strC == nil) {
        strC = [[self sharedBundle] pathForResource:scaleImgName ofType:@"png" inDirectory:@"images"];
    }
    return [UIImage imageWithContentsOfFile:strC];
}

- (void)registerApplicationNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startScan) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopScan) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (void)resignApplicationNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}
#pragma mark - UI getter
- (UIView *)maskView {
    if (!_maskView) {
        _maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        _maskView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
        CGFloat pathWidth = DNKDevice.screenWidth-100;
        CGFloat orginY = (DNKDevice.screenHeight-pathWidth)/2-50;
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[self imageWithName:@"ic_scanBg"]];
        imageView.frame = CGRectMake(50, orginY, pathWidth, pathWidth);
        [self.view addSubview:imageView];
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        animation.duration = 0.25;
        animation.fromValue = @(0);
        animation.toValue = @(1);
        animation.delegate = self;
        [imageView.layer addAnimation:animation forKey:nil];
    }
    return _maskView;
}
- (UIImageView *)scanLineView {
    if (_scanLineView == nil) {
        UIImage *img = [self imageWithName:@"ic_scanLine"];
        _scanLineView = [[UIImageView alloc] initWithImage:img];
        CGFloat pathWidth = DNKDevice.screenWidth - 100;
        CGFloat orginY = (DNKDevice.screenHeight - pathWidth)/2-50;
        CGRect frame = CGRectMake(55, orginY+10, pathWidth-10, 5);
        _scanLineView.frame = frame;
    }
    return _scanLineView;
}
- (CABasicAnimation *)lineAnimation {
    if (_lineAnimation == nil) {
        __weak typeof(self) ws = self;
        CGFloat pathWidth = DNKDevice.screenWidth - 100;
        _lineAnimation = [CABasicAnimation animation];
        _lineAnimation.beginTime = CACurrentMediaTime();
        _lineAnimation.keyPath = @"position.y";
        _lineAnimation.duration = 4.0;
        _lineAnimation.byValue = @(pathWidth-20);
        _lineAnimation.repeatCount = HUGE_VALF;
        _lineAnimation.removedOnCompletion = NO;
        _lineAnimation.delegate = ws;
        _lineAnimation.fillMode = kCAFillModeForwards;
    }
    return _lineAnimation;
}
- (void)initBaseUI {
    CGFloat statusHeight = DNKDevice.statusHeight;
    CGFloat screenWidth = DNKDevice.screenWidth;
    CGFloat screenHeight = DNKDevice.screenHeight;
    UIView *navigationView = UIView.new;
    [self.view addSubview:navigationView];
    _navigationView = navigationView;
    navigationView.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
    navigationView.frame = CGRectMake(0, 0, screenWidth, statusHeight+44);
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [navigationView addSubview:backBtn];
    UIView *lineView = UIView.new;
    [navigationView addSubview:lineView];
    lineView.backgroundColor = hexColor(0xEAEAEA);
    lineView.frame = CGRectMake(0, CGRectGetHeight(navigationView.frame)-0.5, screenWidth, 0.5);
    lineView.alpha = 0;
    _lineView = lineView;
    
    _backButton = backBtn;
    backBtn.frame = CGRectMake(0, statusHeight, 50, 44);
    UIImage *backImg = [self imageWithName:@"ic_back"];
    [backBtn setImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(dismissViewContrller) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth/2-80, statusHeight, 160, 44)];
    [navigationView addSubview:label];
    _navigationTitleLabel = label;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:18];
    label.text = (@"扫描二维码");
    
    CGFloat pathWidth = screenWidth-100;
    CGFloat orginY = (screenHeight-pathWidth)/2-50+pathWidth;
    
    _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, orginY+15, pathWidth, 20)];
    _textLabel.text = (@"扫码绑定");
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.font = [UIFont systemFontOfSize:14];
    _textLabel.textColor = [UIColor colorWithWhite:.7 alpha:1];
    [self.view addSubview:_textLabel];
    
    _torchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _torchBtn.frame = CGRectMake(screenWidth/2-15, orginY+40, 30, 30);
    _torchBtn.hidden = YES;
    [_torchBtn setImage:[self imageWithName:@"torch_n"] forState:UIControlStateNormal];
    [_torchBtn setImage:[self imageWithName:@"torch_s"] forState:UIControlStateSelected];
    [_torchBtn addTarget:self action:@selector(switchTorchClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_torchBtn];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth/2-50, orginY+75, 100, 30)];
    _tipLabel.hidden = YES;
    _tipLabel.text = (@"轻触照亮");
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.font = [UIFont systemFontOfSize:14];
    _tipLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:_tipLabel];
    
    [self.view addSubview:self.maskView];
    [self.view sendSubviewToBack:self.maskView];
    [self.view addSubview:self.scanLineView];
}

- (void)dealloc {
    NSLog(@"===ScanVC === dealloc !!!");
}

@end
