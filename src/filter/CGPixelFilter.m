//
//  CGPixelFilter.m
//  CGPixel
//
//  Created by CGPixel on 2021/5/13.
//  Copyright © 2021 CGPixel. All rights reserved.
//

#import "CGPixelFilter.h"
#import "CGPixelFramebufferCache.h"
#import "CGPixelUtils.h"

/*
 旋转Z
 float radX = 90.0 * PI / 180.0;
 mat4 rotationMatrix = mat4(cos(radX) , sin(radX) , 0.0, 0.0,
                            -sin(radX), cos(radX), 0.0, 0.0,
                            0.0, 0.0, 1.0, 0.0,
                            0.0, 0.0, 0.0, 1.0);
 
 旋转X
 float radX = 150.0 * PI / 180.0;
 mat4 rotationMatrix = mat4(1, 0, 0.0, 0.0,
                            0, cos(radX), sin(radX), 0.0,
                            0.0, -sin(radX), cos(radX), 0.0,
                            0.0, 0.0, 0.0, 1.0);
 
 旋转Y
 float radX = 30.0 * PI / 180.0;
 mat4 rotationMatrix = mat4(cos(radX), 0, -sin(radX), 0,
                            0, 1, 0, 0,
                            sin(radX), 0, cos(radX), 0,
                            0.0, 0.0, 0.0, 1.0);

 
缩放
 mat4 rotationMatrix = mat4(2 , 0 , 0.0, 0.0,
                            0, 2, 0.0, 0.0,
                            0.0, 0.0, 1.0, 0.0,
                            0.0, 0.0, 0.0, 1.0);

 平移
 mat4 rotationMatrix = mat4(1 , 0 , 0, 0,
                            0, 1, 0, 0,
                            0.0, 0.0, 1.0, 0.0,
                            0.2, 0.2, 0.0, 1.0);

 */
NSString *const kCGVertexShaderString = CG_SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 aTexCoord;
 
 varying vec2 vTexCoord;
 
 void main()
 {
    gl_Position = position;
    vTexCoord = aTexCoord.xy;
 }
 );

NSString *const kCGFragmentShaderString = CG_SHADER_STRING
(
 precision highp float;
 varying vec2 vTexCoord;
 
 uniform sampler2D uTexture;
 uniform float a;
 void main()
 {
     gl_FragColor = texture2D(uTexture, vTexCoord);
 }
);

static const GLfloat imageVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

static const GLfloat textureCoordinates[] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
};

@interface CGPixelFilter ()
{
    //Uniform状态Blocks字典
    NSMutableDictionary *uniformStateRestorationBlocks;
    //顶点属性,纹理属性
    GLint _position, _aTexCoord;
    //输入纹理unfiorm
    GLint _uTexture;
    float _bgColor[4];
    
    CGPixelFramebuffer *_inputFramebuffer;
}
@end

@implementation CGPixelFilter

- (instancetype)init
{
    self = [self initWithVertexShader:kCGVertexShaderString fragmentShader:kCGFragmentShaderString];
    if (self) {

    }
    return self;
}
- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader {
    if (!(self = [super init]))
    {
        return nil;
    }
    [self setClearColorRed:1 green:0 blue:0 alpha:0];

    runSyncOnSerialQueue(^{
        [[CGPixelContext sharedRenderContext] useAsCurrentContext];

        self->_shaderProgram = [[CGPixelProgram alloc] initWithVertexShaderString:vertexShader fragmentShaderString:fragmentShader];
        
        glCheckError("CGPaintFilter");
        
        if (self->_shaderProgram && [self->_shaderProgram link]) {
            [self glProgramLinked];
            [self setupAttributes];
            [self setupUniforms];
            glEnableVertexAttribArray(self->_position);
            glEnableVertexAttribArray(self->_aTexCoord);
        }
        glCheckError("CGPaintFilter");
    });
    return self;
}

- (instancetype)initWithFragmentShader:(NSString *)fragmentShader {
    return [self initWithVertexShader:kCGVertexShaderString fragmentShader:fragmentShader];
}

- (void)setupAttributes {
    self->_position = [self->_shaderProgram getAttribLocation:ATTR_POSITION];
    self->_aTexCoord = [self->_shaderProgram getAttribLocation:ATTR_TEXCOORD];
}

- (void)setupUniforms {
    self->_uTexture = [self->_shaderProgram getUniformLocation:UNIF_TEXTURE];
}

#pragma mark -
#pragma mark CGRenderInput

- (void)newFrameReadyAtTime:(CMTime)frameTime framebuffer:(CGPixelFramebuffer *)framebuffer {
    _inputFramebuffer = framebuffer;
    [self glReceivedInput:framebuffer];

    //1.处理自己的滤镜
    [self renderToTextureWithVertices:imageVertices textureCoordinates:textureCoordinates];
    
    //2.通知自己的下一个节点处理滤镜
    [self notifyNextTargetsAboutNewFrameAtTime:frameTime];
    
}

#pragma mark -
#pragma mark Render

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates {
    
    //创建FBO, 生成纹理
    self->_outputFramebuffer = [[CGPixelFramebufferCache sharedFramebufferCache] fetchFramebufferForSize:_inputFramebuffer.fboSize onlyTexture:NO];
    glViewport(0, 0, _inputFramebuffer.fboSize.width, _inputFramebuffer.fboSize.height);
    [self->_outputFramebuffer bindFramebuffer];
    [self->_outputFramebuffer bindTexture];
    //如果未绑定FBO, 执行glValidateProgram函数, 则会出现错误日志: Validation Failed: Current draw framebuffer is invalid*
    NSAssert([self->_shaderProgram validate], @"");
    [self->_shaderProgram use];
    //传递参数一定是program use之后才能传递
    [self glProgramUsed];
    glClearColor(1, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    //开启0号绑定点, 可以理解为0号绑定点就是在显卡上的以为物理位置, 开启意味着可以像这个位置读写数据
    glActiveTexture(GL_TEXTURE0);
    //把_inputFramebuffer.texture这个纹理的id绑定到0号绑定点上, 并且设置是GL_TEXTURE_2D类型, 纹理有多种不同的类型
    //此时0号绑定点上存储的就是_inputFramebuffer.texture纹理id
    glBindTexture(GL_TEXTURE_2D, _inputFramebuffer.texture);
    //在把0号绑定点传输给着色器里的_uTexture位置, 着色器就会从0号绑定点去读取里面的纹理
    glUniform1i(_uTexture, VGX_TEXTURE0);
    
    //这个地方要修改, 使用VBO
    //纹理和顶点坐标一定要是有VBO, 否则某些情况下会出现bug
    //Execution of the command buffer was aborted due to an error during execution. Ignored (for causing prior/excessive GPU errors) (IOAF code 4)
    //------------
    //改为VAO, 更为方便
    //glGenVertexArraysOES(GLsizei n, GLuint *arrays)
    glEnableVertexAttribArray(self->_position);
    //参考OpenGL ES 3.0编程指南第2版, 6.12 顶点数组, 89页
    //如果使用的是顶点数组, 则最后一个参数是顶点数组的指针地址, 如果使用的是VBO, 则最后一个参数表示该数据在缓存中的偏移量
    //倒数第三个参数是是否归一化, 因为我们传的数据就是归一化的数据, 所以不需要归一化
    glVertexAttribPointer(self->_position, 2, GL_FLOAT, 0, 0, vertices);
    glEnableVertexAttribArray(self->_aTexCoord);
    glVertexAttribPointer(self->_aTexCoord, 2, GL_FLOAT, 0, 0, textureCoordinates);
    [self glPrepareRender];
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(self->_aTexCoord);
    glDisableVertexAttribArray(self->_position);
    [self glRenderFinished];
    
    ///神奇的问题, 复用fbo和纹理, 这里一定要执行下glReadPixels, 否则数据确实存在, 但是无法画到renderbuffer上
//    char *mSrcRGBA = (char *)malloc(1);
//    //glReadPixels 读取的是FBO的数据, 不是纹理的数据
//    glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, mSrcRGBA);
//    free(mSrcRGBA);
//    UIImage *image = [CGPaintUtils convertBitmapRGBA8ToUIImage:(char *)mSrcRGBA withWidth:size.width withHeight:size.height];
    [self->_outputFramebuffer unbindFramebuffer];
    [self->_outputFramebuffer unbindTexture];
    [self->_shaderProgram unuse];
//    if (_inputFramebuffer.isOnlyGenTexture == NO) {
//        [_inputFramebuffer recycle];
//    }
}

- (void)notifyNextTargetsAboutNewFrameAtTime:(CMTime)frameTime {
    [_inputFramebuffer recycle];

    for (id<CGPixelInput> currentTarget in _targets) {
        [currentTarget newFrameReadyAtTime:kCMTimeZero framebuffer:self->_outputFramebuffer];
    }
    
    [_outputFramebuffer recycle];
}

#pragma mark -
#pragma mark Input parameters

- (void)setClearColorRed:(GLfloat)red green:(GLfloat)green blue:(GLfloat)blue alpha:(GLfloat)alpha {
    _bgColor[0] = red;
    _bgColor[1] = green;
    _bgColor[2] = blue;
    _bgColor[3] = alpha;
}

- (CGSize)size {
    return _outputFramebuffer.fboSize;
}

#pragma mark -
#pragma mark 子类实现, 处理自己特殊的数据
- (void)glProgramLinked {
    
}
- (void)glReceivedInput:(CGPixelFramebuffer *)framebuffer {
    
}
- (void)glProgramUsed {
    
}
- (void)glPrepareRender {
    
}
- (void)glRenderFinished {
    
}

- (void)setValue:(CGFloat)value {
    _value = value;
}

- (void)setInValue3:(vec_float3)inValue {
    
}
#pragma mark -
#pragma mark Image capture
void dataProviderReleaseCallback (void *info, const void *data, size_t size)
{
    free((void *)data);
}

- (CGImageRef)imageFromCurrentFramebuffer {
    NSAssert(_outputFramebuffer.textureOptions.internalFormat == GL_RGBA, @"For conversion to a CGImage the output texture format for this filter must be GL_RGBA.");
    NSAssert(_outputFramebuffer.textureOptions.type == GL_UNSIGNED_BYTE, @"For conversion to a CGImage the type of the output texture of this filter must be GL_UNSIGNED_BYTE.");
    
    __block CGImageRef cgImageFromBytes;
    runSyncOnSerialQueue(^{
        [[CGPixelContext sharedRenderContext] useAsCurrentContext];
        
        CGSize _size = self->_outputFramebuffer.fboSize;
        NSUInteger totalBytesForImage = (int)_size.width * (int)_size.height * 4;
        // It appears that the width of a texture must be padded out to be a multiple of 8 (32 bytes) if reading from it using a texture cache
        
        GLubyte *rawImagePixels;
        
        CGDataProviderRef dataProvider = NULL;
        [self->_outputFramebuffer bindFramebuffer];
        rawImagePixels = (GLubyte *)malloc(totalBytesForImage);
        glReadPixels(0, 0, (int)_size.width, (int)_size.height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
        dataProvider = CGDataProviderCreateWithData(NULL, rawImagePixels, totalBytesForImage, dataProviderReleaseCallback);
        
        CGColorSpaceRef defaultRGBColorSpace = CGColorSpaceCreateDeviceRGB();
        
        cgImageFromBytes = CGImageCreate((int)_size.width, (int)_size.height, 8, 32, 4 * (int)_size.width, defaultRGBColorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaLast, dataProvider, NULL, NO, kCGRenderingIntentDefault);
        
        // Capture image with current device orientation
        CGDataProviderRelease(dataProvider);
        CGColorSpaceRelease(defaultRGBColorSpace);
        
    });
    
    return cgImageFromBytes;
       
}

- (void)imageFromCurrentFramebuffer:(void (^)(CGImageRef _Nonnull))callback {
    CGImageRef imageRef = [self imageFromCurrentFramebuffer];
    callback(imageRef);
    CGImageRelease(imageRef);
}
- (void)dealloc
{
    
}
@end
