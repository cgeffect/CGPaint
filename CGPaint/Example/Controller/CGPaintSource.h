//
//  CGPaintSource.h
//  CGPaint
//
//  Created by 王腾飞 on 2021/11/5.
//

#import <Foundation/Foundation.h>
@import CoreVideo;

NS_ASSUME_NONNULL_BEGIN

@interface CGPaintSource : NSObject

+ (CVPixelBufferRef)pixelBufferCreate:(OSType)pixelFormatType width:(NSUInteger)width height:(NSUInteger)height;

+ (BOOL)create32BGRAPixelBufferWithNV12:(nonnull UInt8 *)nv12 width:(NSUInteger)width height:(NSUInteger)height dstBuffer:(nonnull CVPixelBufferRef)dstBuffer;

+ (nullable CVPixelBufferRef)create420Yp8_CbCr8PixelBufferWithNV12:(UInt8 *)data width:(NSInteger)width height:(NSInteger)height;
@end

NS_ASSUME_NONNULL_END
