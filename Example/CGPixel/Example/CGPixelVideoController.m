//
//  CGPixelVideoController.m
//  CGPixel
//
//  Created by Jason on 2021/5/31.
//

#import "CGPixelVideoController.h"
#import "CGPixel.h"

@interface CGPixelVideoController ()
{
    CGPixelViewOutput *_paintview;
    CGPixelVideoInput *_inputSource;
    CGPixelSoulFilter *_soul;
    CGPixelGlitchFilter *_glitch;

}
@end

@implementation CGPixelVideoController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    _paintview = [[CGPixelViewOutput alloc] initWithFrame:CGRectMake(0, 100, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.width)];
    _paintview.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:_paintview];
    
    self.navigationItem.title = @"CG_VIDEO";
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"mp4"];
    _inputSource = [[CGPixelVideoInput alloc] initWithURL:[NSURL fileURLWithPath:path]];
        
    UISlider *slide = [[UISlider alloc] initWithFrame:CGRectMake(30, UIScreen.mainScreen.bounds.size.height - 100, UIScreen.mainScreen.bounds.size.width - 60, 50)];
    slide.minimumValue = 0;
    slide.maximumValue = 1;
    [slide addTarget:self action:@selector(valueChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:slide];

    [self setupFilter];
}

- (void)setupFilter {
    _soul = [[CGPixelSoulFilter alloc] init];
    _glitch = [[CGPixelGlitchFilter alloc] init];
    [_inputSource addTarget:_glitch];
    [_glitch addTarget:_soul];
    [_soul addTarget:_paintview];
    [_inputSource requestRender];
}

- (void)valueChange:(UISlider *)slide {
    [_soul setValue:slide.value * 2];
    [_glitch setValue:slide.value * 2];
}
- (void)dealloc
{
    [_inputSource stopRender];
}
@end
