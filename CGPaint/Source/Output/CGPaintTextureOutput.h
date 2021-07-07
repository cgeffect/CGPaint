//
//  CGPaintTextureOutput.h
//  CGPaint
//
//  Created by CGPaint on 2021/5/13.
//  Copyright © 2021 CGPaint. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGPaintInput.h"

NS_ASSUME_NONNULL_BEGIN

@interface CGPaintTextureOutput : NSObject<CGPaintInput>

@property(nonatomic, assign, readonly) GLuint texture;

@property(nonatomic, assign, readonly) CGSize textureSize;

@end

NS_ASSUME_NONNULL_END
