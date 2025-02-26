//
//  CGPixelFramebuffer.m
//  CGPixel
//
//  Created by Jason on 21/3/1.
//

#import "CGPixelFramebuffer.h"
#import "CGPixelOutput.h"
#import "CGPixelContext.h"

@implementation CGPixelFramebuffer
{
    GLuint           _framebuffer;
    GLTex            _texture;
    CGTextureOptions _textureOptions;
    CGSize           _fboSize;
    
    CVPixelBufferRef _renderTarget;
    CVOpenGLESTextureRef renderTexture;
}

#pragma mark -
#pragma mark Usage

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}
- (instancetype)initWithSize:(CGSize)framebufferSize onlyTexture:(BOOL)onlyTexture {
    _textureOptions = [[self class] defaultTextureOption];
    if (!(self = [self initWithSize:framebufferSize textureOptions:_textureOptions onlyTexture:onlyTexture])) {
        return nil;
    }
    
    return self;
}

- (instancetype)initWithSize:(CGSize)framebufferSize textureOptions:(CGTextureOptions)fboTextureOptions onlyTexture:(BOOL)onlyTexture {
    if (!(self = [super init])) {
        return nil;
    }
    _fboSize = framebufferSize;
    _textureOptions = fboTextureOptions;
    _isOnlyGenTexture = onlyTexture;
    [[CGPixelContext sharedRenderContext] useAsCurrentContext];
    if (onlyTexture) {
        [self generateTexture];
    } else {
        [self generateFramebuffer];
        
    }
    return self;
}

- (instancetype)initWithSize:(CGSize)framebufferSize texture:(GLuint)texture {
    self = [super init];
    if (self) {
        [self updateWithSize:framebufferSize texture:texture];
    }
    return self;
}
- (void)updateWithSize:(CGSize)framebufferSize texture:(GLuint)texture {
    _texture = texture;
    _fboSize = framebufferSize;
}

- (CGSize)fboSize {
    return _fboSize;
}

- (GLuint) texture {
    return _texture;
}

- (CGTextureOptions)textureOptions {
    return _textureOptions;
}

+ (CGTextureOptions)defaultTextureOption {
    CGTextureOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    return defaultTextureOptions;
}

- (void)bindFramebuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glCheckError("bindFramebuffer");
}

- (void)unbindFramebuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, GL_NONE);
    glCheckError("unbindFramebuffer");
}
- (void)bindTexture {
    glBindTexture(GL_TEXTURE_2D, _texture);
    glCheckError("bindTexture");
}

- (void)unbindTexture {
    glBindTexture(GL_TEXTURE_2D, GL_NONE);
    glCheckError("unbindTexture");
}

- (void)upload:(GLubyte *)data size:(CGSize)size internalformat:(GLenum)internalformat format:(GLenum)format isOverride:(BOOL)isOverride {
    if (isOverride) {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, size.width, size.height, format, GL_UNSIGNED_BYTE, data);
    } else {
        //GL_UNSIGNED_BYTE的含义的无符号整形占4个字节, 和format士对应的, 比如format是RGBA8888, 正好是4个字节
        glTexImage2D(GL_TEXTURE_2D, 0, internalformat, size.width, size.height, 0, format, GL_UNSIGNED_BYTE, data);
    }
}

- (void)dealloc {
    runSyncOnSerialQueue(^{
        [[CGPixelContext sharedRenderContext] useAsCurrentContext];
        if (self->_framebuffer) {
            glDeleteFramebuffers(1, &self->_framebuffer);
            self->_framebuffer = GL_NONE;
        }
        
        if (self->_isOnlyGenTexture) {
            if (self->_texture) {
                glDeleteTextures(1, &self->_texture);
                self->_texture = GL_NONE;
            }
        } else {
            if ([CGPixelContext supportsFastTextureUpload]) {
                if (self->_renderTarget) {
                    CFRelease(self->_renderTarget);
                    self->_renderTarget = NULL;
                }
                
                if (self->renderTexture) {
                    CFRelease(self->renderTexture);
                    self->renderTexture = NULL;
                }
            } else {
                if (self->_texture) {
                    glDeleteTextures(1, &self->_texture);
                    self->_texture = GL_NONE;
                }
            }
        }
        NSLog(@"%@ dealloc", self);
    });
}

#pragma mark -
#pragma mark Internal

- (void)generateTexture {
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
}

- (void)generateFramebuffer {
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    if ([CGPixelContext supportsFastTextureUpload]) {
        CVOpenGLESTextureCacheRef coreVideoTextureCache = [[CGPixelContext sharedRenderContext] coreVideoTextureCache];
        CFDictionaryRef empty; // empty value for attr value.
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);

        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)_fboSize.width, (int)_fboSize.height, kCVPixelFormatType_32BGRA, attrs, &_renderTarget);
        if (err)
        {
            NSLog(@"FBO size: %f, %f", _fboSize.width, _fboSize.height);
            NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
        }
        err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault,
                                                            coreVideoTextureCache,
                                                            _renderTarget,
                                                            NULL, // texture attributes
                                                            GL_TEXTURE_2D,
                                                            _textureOptions.internalFormat, // opengl format
                                                            (int)_fboSize.width,
                                                            (int)_fboSize.height,
                                                            _textureOptions.format, // native iOS format
                                                            _textureOptions.type,
                                                            0,
                                                            &renderTexture);
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }

        CFRelease(attrs);
        CFRelease(empty);

        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        _texture = CVOpenGLESTextureGetName(renderTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
        [self generateTexture];
        glBindTexture(GL_TEXTURE_2D, _texture);
        glTexImage2D(GL_TEXTURE_2D, 0, _textureOptions.internalFormat, (int)_fboSize.width, (int)_fboSize.height, 0, _textureOptions.format, _textureOptions.type, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glCheckError("glCheckFramebufferStatus");
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"FBO size: %f, %f", _fboSize.width, _fboSize.height);
        NSAssert(NO, @"Incomplete filter FBO: %d", status);
    }
}

//- (GLubyte *)byteBuffer
//{
//    CVPixelBufferLockBaseAddress(_renderTarget, 0);
//    GLubyte * bufferBytes = CVPixelBufferGetBaseAddress(_renderTarget);
//    CVPixelBufferUnlockBaseAddress(_renderTarget, 0);
//    return bufferBytes;
//}

- (CVPixelBufferRef)renderTarget {
    return _renderTarget;
}

- (void)recycle {
    [[CGPixelFramebufferCache sharedFramebufferCache] recycleFramebufferToCache:self];
}
@end
