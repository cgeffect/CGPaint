//
//  CGPixelRawDataOutput.h
//  CGPixel
//
//  Created by CGPixel on 2021/5/13.
//

#import <Foundation/Foundation.h>
#import "CGPixelFramebuffer.h"
#import "CGPixelInput.h"
#import "CGPixelContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface CGPixelRawDataOutput : NSObject<CGPixelInput>
//仅支持RGBA格式
@property(nonatomic, copy)void(^outputCallback)(NSData *data);

/**
 是否输出
  
 @property enableOutput 启用输出, 默认为NO
 @discussion 可动态配置, YES输出, NO禁用
 */
@property(nonatomic, assign)BOOL enableOutput;

@end

NS_ASSUME_NONNULL_END
