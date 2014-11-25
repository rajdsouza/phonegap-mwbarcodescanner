/*
 * Copyright (C) 2012  Manatee Works, Inc.
 *
 */

#import "MWScannerViewController.h"
#import "BarcodeScanner.h"
#import "MWOverlay.h"
#include <mach/mach_host.h>

// !!! Rects are in format: x, y, width, height !!!
#define RECT_LANDSCAPE_1D       6, 20, 88, 60
#define RECT_LANDSCAPE_2D       20, 6, 60, 88
#define RECT_PORTRAIT_1D        20, 6, 60, 88
#define RECT_PORTRAIT_2D        20, 6, 60, 88
#define RECT_FULL_1D            6, 6, 88, 88
#define RECT_FULL_2D            20, 6, 60, 88
#define RECT_DOTCODE            30, 20, 40, 60


UIInterfaceOrientationMask param_Orientation = UIInterfaceOrientationMaskLandscapeLeft;
BOOL param_EnableHiRes = YES;
BOOL param_EnableFlash = YES;
BOOL param_EnableZoom = YES;
BOOL param_defaultFlashOn = NO;
int param_OverlayMode = OM_MW;
int param_ZoomLevel1 = 0;
int param_ZoomLevel2 = 0;
int zoomLevel = 0;


static NSString *DecoderResultNotification = @"DecoderResultNotification";

@implementation MWScannerViewController {
    AVCaptureSession *_captureSession;
	AVCaptureDevice *_device;
	UIImageView *_imageView;
	CALayer *_customLayer;
	AVCaptureVideoPreviewLayer *_prevLayer;
	bool running;
    NSString * lastFormat;
	
	MainScreenState state;
	
	CGImageRef	decodeImage;
	NSString *	decodeResult;
	int width;
	int height;
	int bytesPerRow;
	unsigned char *baseAddress;
    NSTimer *focusTimer;
    
    BOOL statusBarHidden;
}

@synthesize captureSession = _captureSession;
@synthesize prevLayer = _prevLayer;
@synthesize device = _device;
@synthesize state;
@synthesize focusTimer;
@synthesize flashButton;
@synthesize zoomButton;

#pragma mark -
#pragma mark Initialization

+ (void) initDecoder {
    //You can now register codes from MWBScanner.js!
    
   /* MWB_registerCode(MWB_CODE_MASK_39,      "username", "key");
    MWB_registerCode(MWB_CODE_MASK_93,      "username", "key");
    MWB_registerCode(MWB_CODE_MASK_25,      "username", "key");
    MWB_registerCode(MWB_CODE_MASK_128,     "username", "key");
    MWB_registerCode(MWB_CODE_MASK_AZTEC,   "username", "key");
    MWB_registerCode(MWB_CODE_MASK_DM,      "username", "key");
    MWB_registerCode(MWB_CODE_MASK_EANUPC,  "username", "key");
    MWB_registerCode(MWB_CODE_MASK_QR,      "username", "key");
    MWB_registerCode(MWB_CODE_MASK_PDF,     "username", "key");
    MWB_registerCode(MWB_CODE_MASK_RSS,     "username", "key");
    MWB_registerCode(MWB_CODE_MASK_CODABAR, "username", "key");
    MWB_registerCode(MWB_CODE_MASK_DOTCODE, "username", "key");*/
    
    
    // choose code type or types you want to search for
    
    // Our sample app is configured by default to search all supported barcodes...
    MWB_setActiveCodes(MWB_CODE_MASK_25    |
                       MWB_CODE_MASK_39     |
                       MWB_CODE_MASK_93     |
                       MWB_CODE_MASK_128    |
                       MWB_CODE_MASK_AZTEC  |
                       MWB_CODE_MASK_DM     |
                       MWB_CODE_MASK_EANUPC |
                       MWB_CODE_MASK_PDF    |
                       MWB_CODE_MASK_QR     |
                       MWB_CODE_MASK_CODABAR|
                       MWB_CODE_MASK_RSS);
    
    // But for better performance, only activate the symbologies your application requires...
    // MWB_setActiveCodes( MWB_CODE_MASK_25 );
    // MWB_setActiveCodes( MWB_CODE_MASK_39 );
    // MWB_setActiveCodes( MWB_CODE_MASK_93 );
    // MWB_setActiveCodes( MWB_CODE_MASK_128 );
    // MWB_setActiveCodes( MWB_CODE_MASK_AZTEC );
    // MWB_setActiveCodes( MWB_CODE_MASK_DM );
    // MWB_setActiveCodes( MWB_CODE_MASK_EANUPC );
    // MWB_setActiveCodes( MWB_CODE_MASK_PDF );
    // MWB_setActiveCodes( MWB_CODE_MASK_QR );
    // MWB_setActiveCodes( MWB_CODE_MASK_RSS );
    // MWB_setActiveCodes( MWB_CODE_MASK_CODABAR );
    // MWB_setActiveCodes( MWB_CODE_MASK_DOTCODE );
    
    
    // Our sample app is configured by default to search both directions...
    MWB_setDirection(MWB_SCANDIRECTION_HORIZONTAL | MWB_SCANDIRECTION_VERTICAL);
    // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
    MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_FULL_2D);
    MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_FULL_2D);
    MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_FULL_2D);
    MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_FULL_1D);
    MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE);
    
    
    // But for better performance, set like this for PORTRAIT scanning...
    // MWB_setDirection(MWB_SCANDIRECTION_VERTICAL);
    // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
    // MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_PORTRAIT_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_PORTRAIT_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_PORTRAIT_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_PORTRAIT_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE);
    
    // or like this for LANDSCAPE scanning - Preferred for dense or wide codes...
    // MWB_setDirection(MWB_SCANDIRECTION_HORIZONTAL);
    // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
    // MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_LANDSCAPE_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_LANDSCAPE_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_LANDSCAPE_2D);
    // MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_LANDSCAPE_1D);
    // MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE);
    
    
    // set decoder effort level (1 - 5)
    // for live scanning scenarios, a setting between 1 to 3 will suffice
    // levels 4 and 5 are typically reserved for batch scanning
    MWB_setLevel(2);
    
    //get and print Library version
    int ver = MWB_getLibVersion();
    int v1 = (ver >> 16);
    int v2 = (ver >> 8) & 0xff;
    int v3 = (ver & 0xff);
    NSString *libVersion = [NSString stringWithFormat:@"%d.%d.%d", v1, v2, v3];
    NSLog(@"Lib version: %@", libVersion);
}
    
+ (void) setInterfaceOrientation: (UIInterfaceOrientationMask) interfaceOrientation {
    
    param_Orientation = interfaceOrientation;
    
}
    
+ (void) enableHiRes: (BOOL) hiRes {
    
    param_EnableHiRes = hiRes;
    
}

+ (void) enableFlash: (BOOL) flash {
    
    param_EnableFlash = flash;
    
}

+ (void) turnFlashOn: (BOOL) flashOn {
    
    param_defaultFlashOn = flashOn;
    
}
    
+ (void) setOverlayMode: (int) overlayMode {
    
    param_OverlayMode = overlayMode;
    
}

+ (void) enableZoom: (BOOL) zoom {
    
    param_EnableZoom = zoom;
    
}

+ (void) setZoomLevels: (int) zoomLevel1 zoomLevel2: (int) zoomLevel2 initialZoomLevel: (int) initialZoomLevel {
    
    param_ZoomLevel1 = zoomLevel1;
    param_ZoomLevel2 = zoomLevel2;
    zoomLevel = initialZoomLevel;
    if (zoomLevel > 2){
        zoomLevel = 2;
    }
    if (zoomLevel < 0){
        zoomLevel = 0;
    }
    
}



- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    statusBarHidden =  [[UIApplication sharedApplication] isStatusBarHidden];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    flashButton.hidden = !param_EnableFlash;
    zoomButton.hidden = !param_EnableZoom;
    
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"On iOS simulator camera is not Supported");
#else
	[self initCapture];
#endif
    
    if (param_OverlayMode & OM_MW){
        [MWOverlay addToPreviewLayer:self.prevLayer];
    }
    
    cameraOverlay.hidden = !(param_OverlayMode & OM_IMAGE);
    
    
    if (param_EnableFlash && [self.device isTorchModeSupported:AVCaptureTorchModeOn] && param_defaultFlashOn){
        if ([self.device lockForConfiguration:NULL]) {
            if ([self.device torchMode] == AVCaptureTorchModeOff){
                [self.device setTorchMode:AVCaptureTorchModeOn];
                flashButton.selected = YES;
            }
        }
    }
    
    
    [self updateTorch];
    
    
}

- (void)viewWillDisappear:(BOOL) animated {
    [super viewWillDisappear:animated];
    if (param_EnableFlash && [self.device isTorchModeSupported:AVCaptureTorchModeOn] && [self.device lockForConfiguration:NULL]) {
        if ([self.device torchMode] == AVCaptureTorchModeOn){
            [self.device setTorchMode:AVCaptureTorchModeOff];
            flashButton.selected = NO;
        }
    }
    [self stopScanning];
    [self deinitCapture];
    flashButton.selected = NO;
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startScanning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.prevLayer = nil;
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(decodeResultNotification:) name: DecoderResultNotification object: nil];
    

}

// IOS 7 statusbar hide
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


-(void) reFocus {
   //NSLog(@"refocus");

    NSError *error;
    if ([self.device lockForConfiguration:&error]) {
        
        if ([self.device isFocusPointOfInterestSupported]){
            [self.device setFocusPointOfInterest:CGPointMake(0.49,0.49)];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        [self.device unlockForConfiguration];
        
    }
}

- (void) updateTorch {
    
    if (param_EnableFlash && [self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        
        flashButton.hidden = NO;
        
    } else {
        flashButton.hidden = YES;
    }

}
    
- (void)toggleTorch
{
    if ([self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        NSError *error;
        
        if ([self.device lockForConfiguration:&error]) {
            if ([self.device torchMode] == AVCaptureTorchModeOn){
                [self.device setTorchMode:AVCaptureTorchModeOff];
                flashButton.selected = NO;
            }
            else {
                [self.device setTorchMode:AVCaptureTorchModeOn];
                flashButton.selected = YES;
            }
            
            if([self.device isFocusModeSupported: AVCaptureFocusModeContinuousAutoFocus])
                self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            
            [self.device unlockForConfiguration];
        } else {
            
        }
    }
}

- (void) updateDigitalZoom {
   
    if (videoZoomSupported){
        
        [self.device lockForConfiguration:nil];
        
        switch (zoomLevel) {
            case 0:
                [self.device setVideoZoomFactor:1 /*rampToVideoZoomFactor:1 withRate:4*/];
                break;
            case 1:
                [self.device setVideoZoomFactor:firstZoom /*rampToVideoZoomFactor:firstZooom withRate:4*/];
                break;
            case 2:
                [self.device setVideoZoomFactor:secondZoom /*rampToVideoZoomFactor:secondZoom withRate:4*/];
                break;
                
            default:
                break;
        }
        [self.device unlockForConfiguration];
        
       zoomButton.hidden = !param_EnableZoom;
    } else {
        zoomButton.hidden = true;
    }
}

- (void) deinitCapture {
    if (self.captureSession != nil){
        [focusTimer invalidate];
        
        if (param_OverlayMode & OM_MW){
            [MWOverlay removeFromPreviewLayer];
        }
        
#if !__has_feature(objc_arc)
        [self.captureSession release];
#endif
        self.captureSession=nil;
        
        [self.prevLayer removeFromSuperlayer];
        self.prevLayer = nil;
        
    }
}


- (void)initCapture
{
	/*We setup the input*/
	self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	captureOutput.alwaysDiscardsLateVideoFrames = YES;
	//captureOutput.minFrameDuration = CMTimeMake(1, 10); Uncomment it to specify a minimum duration for each video frame
	[captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
	// Set the video output to store frame in BGRA (It is supposed to be faster)
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
	// Set the video output to store frame in 422YpCbCr8(It is supposed to be faster)
	
	//************************Note this line
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
	
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
	[captureOutput setVideoSettings:videoSettings];
    
	//And we create a capture session
	self.captureSession = [[AVCaptureSession alloc] init];
	//We add input and output
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:captureOutput];
    
    
    
    
    if (param_EnableHiRes && [self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
    {
        NSLog(@"Set preview port to 1280X720");
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    } else
        //set to 640x480 if 1280x720 not supported on device
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480])
        {
            NSLog(@"Set preview port to 640X480");
            self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        }
    
    // Limit camera FPS to 15 for single core devices (iPhone 4 and older) so more CPU power is available for decoder
    host_basic_info_data_t hostInfo;
    mach_msg_type_number_t infoCount;
    infoCount = HOST_BASIC_INFO_COUNT;
    host_info( mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount ) ;
    
    if (hostInfo.max_cpus < 2){
        if ([self.device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)]){
            [self.device lockForConfiguration:nil];
            [self.device setActiveVideoMinFrameDuration:CMTimeMake(1, 15)];
            [self.device unlockForConfiguration];
        } else {
            AVCaptureConnection *conn = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
            [conn setVideoMinFrameDuration:CMTimeMake(1, 15)];
        }
    }
    
	/*We add the preview layer*/
    
    self.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    float screenWidth = screenRect.size.width;
    float screenHeight = screenRect.size.height;
    
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft){
        self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        self.prevLayer.frame = CGRectMake(0, 0, MAX(screenWidth, screenHeight), MIN(screenWidth, screenHeight));
    }
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight){
        self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        self.prevLayer.frame = CGRectMake(0, 0, MAX(screenWidth, screenHeight), MIN(screenWidth, screenHeight));
    }
    
    
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait) {
        self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        self.prevLayer.frame = CGRectMake(0, 0, MIN(screenWidth, screenHeight), MAX(screenWidth, screenHeight));
    }
    if (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        self.prevLayer.frame = CGRectMake(0, 0, MIN(screenWidth, screenHeight), MAX(screenWidth, screenHeight));
    }
    
	self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
	[self.view.layer addSublayer: self.prevLayer];
    
    if (![self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        flashButton.hidden = YES;
    }
    
    videoZoomSupported = false;
    
    if ([self.device respondsToSelector:@selector(setActiveFormat:)] &&
        [self.device.activeFormat respondsToSelector:@selector(videoMaxZoomFactor)] &&
        [self.device respondsToSelector:@selector(setVideoZoomFactor:)]){
        
        float maxZoom = 0;
        if ([self.device.activeFormat respondsToSelector:@selector(videoZoomFactorUpscaleThreshold)]){
                maxZoom = self.device.activeFormat.videoZoomFactorUpscaleThreshold;
        } else {
                maxZoom = self.device.activeFormat.videoMaxZoomFactor;
        }
        
        float maxZoomTotal = self.device.activeFormat.videoMaxZoomFactor;
        
        if ([self.device respondsToSelector:@selector(setVideoZoomFactor:)] && maxZoomTotal > 1.1){
            videoZoomSupported = true;
            
            
            
            if (param_ZoomLevel1 != 0 && param_ZoomLevel2 != 0){
                
                if (param_ZoomLevel1 > maxZoomTotal * 100){
                    param_ZoomLevel1 = (int)(maxZoomTotal * 100);
                }
                if (param_ZoomLevel2 > maxZoomTotal * 100){
                    param_ZoomLevel2 = (int)(maxZoomTotal * 100);
                }
                
                firstZoom = 0.01 * param_ZoomLevel1;
                secondZoom = 0.01 * param_ZoomLevel2;
                
                
            } else {
                
                if (maxZoomTotal > 2){
                    
                    if (maxZoom > 1.0 && maxZoom <= 2.0){
                        firstZoom = maxZoom;
                        secondZoom = maxZoom * 2;
                    } else
                        if (maxZoom > 2.0){
                            firstZoom = 2.0;
                            secondZoom = 4.0;
                        }
                    
                }
            }

            
        } else {
            
        }
        
        
        
        
    }
    
    if (!videoZoomSupported){
        zoomButton.hidden = true;
    } else {
        [self updateDigitalZoom];
    }
    
    [self.view bringSubviewToFront:cameraOverlay];
    [self.view bringSubviewToFront:closeButton];
    [self.view bringSubviewToFront:flashButton];
    [self.view bringSubviewToFront:zoomButton];
    

    
    self.focusTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(reFocus) userInfo:nil repeats:YES];
    
    
}

- (void) onVideoStart: (NSNotification*) note
{
    if(running)
        return;
    running = YES;
    
    // lock device and set focus mode
    NSError *error = nil;
    if([self.device lockForConfiguration: &error])
    {
        if([self.device isFocusModeSupported: AVCaptureFocusModeContinuousAutoFocus])
            self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
}

- (void) onVideoStop: (NSNotification*) note
{
    if(!running)
        return;
    [self.device unlockForConfiguration];
    running = NO;
}

#pragma mark -
#pragma mark AVCaptureSession delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
	if (state != CAMERA) {
		return;
	}
	
	if (self.state != CAMERA_DECODING)
	{
		self.state = CAMERA_DECODING;
	}
	
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //Lock the image buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    //Get information about the image
    baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
    int pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
	switch (pixelFormat) {
		case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
			//NSLog(@"Capture pixel format=NV12");
			bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
			width = bytesPerRow;//CVPixelBufferGetWidthOfPlane(imageBuffer,0);
			height = CVPixelBufferGetHeightOfPlane(imageBuffer,0);
			break;
		case kCVPixelFormatType_422YpCbCr8:
			//NSLog(@"Capture pixel format=UYUY422");
			bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
			width = CVPixelBufferGetWidth(imageBuffer);
			height = CVPixelBufferGetHeight(imageBuffer);
			int len = width*height;
			int dstpos=1;
			for (int i=0;i<len;i++){
				baseAddress[i]=baseAddress[dstpos];
				dstpos+=2;
			}
			
			break;
		default:
			//	NSLog(@"Capture pixel format=RGB32");
			break;
	}
	
	unsigned char *frameBuffer = malloc(width * height);
    memcpy(frameBuffer, baseAddress, width * height);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        unsigned char *pResult=NULL;
        
        int resLength = MWB_scanGrayscaleImage(frameBuffer,width,height, &pResult);
        free(frameBuffer);
        //NSLog(@"Frame decoded");
        
        
        
        //ignore results less than 4 characters - probably false detection
        if (resLength > 4 || ((resLength > 0 && MWB_getLastType() != FOUND_39 && MWB_getLastType() != FOUND_25_INTERLEAVED && MWB_getLastType() != FOUND_25_STANDARD)))
        {
            int bcType = MWB_getLastType();
            NSString *typeName=@"";
            switch (bcType) {
                case FOUND_128: typeName = @"Code 128";break;
                case FOUND_39: typeName = @"Code 39";break;
                case FOUND_93: typeName = @"Code 93";break;
                case FOUND_25_INTERLEAVED: typeName = @"Code 25 Interleaved";break;
                case FOUND_25_STANDARD: typeName = @"Code 25 Standard";break;
                case FOUND_AZTEC: typeName = @"AZTEC";break;
                case FOUND_DM: typeName = @"Datamatrix";break;
                case FOUND_QR: typeName = @"QR";break;
                case FOUND_EAN_13: typeName = @"EAN 13";break;
                case FOUND_EAN_8: typeName = @"EAN 8";break;
                case FOUND_NONE: typeName = @"None";break;
                case FOUND_RSS_14: typeName = @"Databar 14";break;
                case FOUND_RSS_14_STACK: typeName = @"Databar 14 Stacked";break;
                case FOUND_RSS_EXP: typeName = @"Databar Expanded";break;
                case FOUND_RSS_LIM: typeName = @"Databar Limited";break;
                case FOUND_UPC_A: typeName = @"UPC A";break;
                case FOUND_UPC_E: typeName = @"UPC E";break;
                case FOUND_PDF: typeName = @"PDF417";break;
                case FOUND_CODABAR: typeName = @"Codabar";break;
            }
            
            lastFormat = typeName;
            
            
            
            
            
            int size=resLength;
            
            char *temp = (char *)malloc(size+1);
            memcpy(temp, pResult, size+1);
            NSString *resultString = [[NSString alloc] initWithBytes: temp length: size encoding: NSUTF8StringEncoding];
            
            NSLog(@"Detected %@: %@", lastFormat, resultString);
             self.state = CAMERA;
            
            
            
            NSMutableString *binString = [[NSMutableString alloc] init];
            
            for (int i = 0; i < size; i++)
                [binString appendString:[NSString stringWithFormat:@"%c", temp[i]]];
            
            if (MWB_getLastType() == FOUND_PDF || resultString == nil)
                resultString = [binString copy];
            else
                resultString = [resultString copy];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (decodeImage != nil)
                {
                    CGImageRelease(decodeImage);
                    decodeImage = nil;
                }
                
                [self.captureSession stopRunning];
                NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
                DecoderResult *notificationResult = [DecoderResult createSuccess:resultString format:typeName rawResult:[[NSData alloc] initWithBytes:pResult length:size]];
                [center postNotificationName:DecoderResultNotification object: notificationResult];
                
                free(temp);
                free(pResult);
            });
            
            
            
        }
        else
        {
            self.state = CAMERA;
        }
	 });
}

- (IBAction)doClose:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
    NSLog(@"I am here");
    [self.delegate scanningFinished:@"" withType:@"Cancel" andRawResult:[[NSData alloc] init]];
    
}
    
- (IBAction)doFlashToggle:(id)sender {
    
    [self toggleTorch];
    
}

- (IBAction)doZoomToggle:(id)sender {
    
    zoomLevel++;
    if (zoomLevel > 2){
        zoomLevel = 0;
    }
    
    [self updateDigitalZoom];
    
}

#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload
{
	[self stopScanning];
	
	self.prevLayer = nil;
	[super viewDidUnload];
}

- (void)dealloc {
#if !__has_feature(objc_arc)
   [super dealloc];
#endif
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) startScanning {
	self.state = LAUNCHING_CAMERA;
	[self.captureSession startRunning];
	self.prevLayer.hidden = NO;
	self.state = CAMERA;
}

- (void)stopScanning {
	if (self.state == CAMERA_DECODING) {
		self.state = CANCELLING;
		return;
	}
	
	[self revertToNormal];
}

- (void)revertToNormal {
	
	[self.captureSession stopRunning];
	self.state = NORMAL;
}

- (void)decodeResultNotification: (NSNotification *)notification {
	
	if ([notification.object isKindOfClass:[DecoderResult class]])
	{
		DecoderResult *obj = (DecoderResult*)notification.object;
		if (obj.succeeded)
		{
                       
            [self dismissModalViewControllerAnimated:YES];
            [self.delegate scanningFinished:obj.result withType: obj.format andRawResult: obj.rawResult];
            
            
		}
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self startScanning];
    }
}

- (NSUInteger)supportedInterfaceOrientations {
    
    return param_Orientation;
}

- (BOOL) shouldAutorotate {
    
    return YES;
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


@end

/*
 *  Implementation of the object that returns decoder results (via the notification
 *	process)
 */

@implementation DecoderResult

@synthesize succeeded;
@synthesize result, format, rawResult;

+(DecoderResult *)createSuccess:(NSString *)result format: (NSString *) format rawResult:(NSData *)rawResult{
	DecoderResult *obj = [[DecoderResult alloc] init];
    obj.succeeded = YES;
	obj.result = result;
    obj.rawResult = rawResult;
    obj.format = format;
	return obj;
}

+(DecoderResult *)createFailure {
	DecoderResult *obj = [[DecoderResult alloc] init];
	if (obj != nil) {
		obj.succeeded = NO;
		obj.result = nil;
        obj.rawResult = nil;
	}
	return obj;
}

- (void)dealloc {
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
    
	self.result = nil;
}

@end