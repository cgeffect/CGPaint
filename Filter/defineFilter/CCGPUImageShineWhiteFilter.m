//
//  CCGPUImageShineWhiteFilter.m
//  CCBeautifulCamera
//
//  Created by 王腾飞 on 2019/6/18.
//  Copyright © 2019年 Selfie. All rights reserved.
//

#import "CCGPUImageShineWhiteFilter.h"

NSString * const kCCGPUImageShineWhiteFilterShaderString = SHADER_STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 varying vec2 textureCoordinate;
 
 uniform float time;
 
 const float PI = 3.1415926;
 
 void main (void) {
     float duration = 0.7;
     
     float currentTime = mod(time, duration);
     
     vec4 whiteMask = vec4(1.0, 1.0, 1.0, 1.0);
     float amplitude = abs(sin(currentTime * (PI / duration)));
     
     vec4 mask = texture2D(inputImageTexture, textureCoordinate);
     
     gl_FragColor = mask * (1.0 - amplitude) + whiteMask * amplitude;
 }
);

@implementation CCGPUImageShineWhiteFilter

- (instancetype)init {
    self = [super initWithFragmentShaderFromString:kCCGPUImageShineWhiteFilterShaderString];
    return self;
}

@end
