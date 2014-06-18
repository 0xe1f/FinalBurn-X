//
//  AKScreenView.mm
//  FinalBurn X
//
//  Created by Akop Karapetyan on 6/17/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#include <OpenGL/gl.h>
#include <time.h>

#import "AKScreenView.h"

@implementation AKScreenView

#pragma mark - Initialize, Dealloc

- (void)dealloc
{
//    glDeleteTextures(1, &screenTexId);
//    
//    for (int i = 0; i < 2; i++)
//        [screens[i] release];
//
    [super dealloc];
}

- (void)awakeFromNib
{
    [[self window] setAcceptsMouseMovedEvents:YES];
    
//    for (int i = 0; i < 2; i++)
//        screens[i] = nil;
}

#pragma mark - Cocoa Callbacks

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
//    // Synchronize buffer swaps with vertical refresh rate
//    GLint swapInt = 1;
//    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
//    
//    glClearColor(0, 0, 0, 1.0);
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//    glEnable(GL_TEXTURE_2D);
//    glGenTextures(1, &screenTexId);
//    
//    glBindTexture(GL_TEXTURE_2D, screenTexId);
//    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//    
//    for (int i = 0; i < 2; i++)
//    {
//        [screens[i] release];
//        screens[i] = [[CMCocoaBuffer alloc] initWithWidth:BUFFER_WIDTH
//                                                   height:HEIGHT
//                                                    depth:DEPTH
//                                                     zoom:ZOOM];
//    }
//    
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB,
//                 screens[0]->textureWidth,
//                 screens[0]->textureHeight,
//                 0, GL_RGBA, GL_UNSIGNED_BYTE,
//                 screens[0]->pixels);
//    
//    glDisable(GL_TEXTURE_2D);
//    
//    // Create a display link capable of being used with all active displays
//    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
//    
//    // Set the renderer output callback function
//    CVDisplayLinkSetOutputCallback(displayLink, &renderCallback, self);
//    
//    // Set the display link for the current renderer
//    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
//    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
//    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
//    
//    // Activate the display link
////    CVDisplayLinkStart(displayLink);
//    
//#ifdef DEBUG
//    NSLog(@"MsxDisplayView: initialized");
//#endif
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [self renderScreen];
//}
//
//- (void)reshape
//{
//    [[self openGLContext] makeCurrentContext];
//    [[self openGLContext] update];
//    
//    NSSize size = [self bounds].size;
//    
//#ifdef DEBUG
//    NSLog(@"MsxDisplayView: resized to %.00fx%.00f", size.width, size.height);
//#endif
//    
//    glViewport(0, 0, size.width, size.height);
//    glMatrixMode(GL_PROJECTION);
//    glLoadIdentity();
//    glOrtho(0, size.width, size.height, 0, -1, 1);
//    glMatrixMode(GL_MODELVIEW);
//    
//    glClear(GL_COLOR_BUFFER_BIT);
//}

#pragma mark - Emulator-specific graphics code

//- (void)renderScreen
//{
//    NSOpenGLContext *nsContext = [self openGLContext];
//    [nsContext makeCurrentContext];
//    
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//    if (!emulator.isInitialized)
//    {
//        [nsContext flushBuffer];
//        return;
//    }
//    
//    CGLContextObj cglContext = [nsContext CGLContextObj];
//    
//    CGLLockContext(cglContext);
//    
//    framesPerSecond = [frameCounter update];
//    [emulator updateFps:framesPerSecond];
//    
//    Properties *properties = emulator.properties;
//    Video *video = emulator.video;
//    FrameBuffer* frameBuffer = frameBufferFlipViewFrame(properties->emulation.syncMethod == P_EMU_SYNCTOVBLANKASYNC);
//    
//    CMCocoaBuffer *currentScreen = screens[currentScreenIndex];
//    
//    char* dpyData = currentScreen->pixels;
//    int width = currentScreen->actualWidth;
//    int height = currentScreen->actualHeight;
//    
//    if (frameBuffer == NULL)
//        frameBuffer = frameBufferGetWhiteNoiseFrame();
//    
//    int borderWidth = (BUFFER_WIDTH - frameBuffer->maxWidth) * currentScreen->zoom / 2;
//    const int linesPerBlock = 4;
//    GLfloat coordX = currentScreen->textureCoordX;
//    GLfloat coordY = currentScreen->textureCoordY;
//    int y;
//    
//    videoRender(video, frameBuffer, currentScreen->depth, currentScreen->zoom,
//                dpyData + borderWidth * currentScreen->bytesPerPixel, 0,
//                currentScreen->pitch, -1);
//    
//    if (borderWidth > 0)
//    {
//        int h = height;
//        while (h--)
//        {
//            memset(dpyData, 0, borderWidth * currentScreen->bytesPerPixel);
//            memset(dpyData + (width - borderWidth) * currentScreen->bytesPerPixel,
//                   0, borderWidth * currentScreen->bytesPerPixel);
//            
//            dpyData += currentScreen->pitch;
//        }
//    }
//    
//    glEnable(GL_TEXTURE_2D);
//    glBindTexture(GL_TEXTURE_2D, screenTexId);
//    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
//    
//    for (y = 0; y < height; y += linesPerBlock)
//        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, y, width, linesPerBlock,
//                        GL_RGBA, GL_UNSIGNED_BYTE,
//                        currentScreen->pixels + y * currentScreen->pitch);
//    
//    NSSize size = [self bounds].size;
//    
//    CGFloat widthRatio = size.width / (CGFloat)ACTUAL_WIDTH;
//    CGFloat offset = ((BUFFER_WIDTH - ACTUAL_WIDTH) / 2.0) * widthRatio;
//    
//    glBegin(GL_QUADS);
//    glTexCoord2f(0.0, 0.0);
//    glVertex3f(-offset, 0.0, 0.0);
//    glTexCoord2f(coordX, 0.0);
//    glVertex3f(size.width + offset, 0.0, 0.0);
//    glTexCoord2f(coordX, coordY);
//    glVertex3f(size.width + offset, size.height, 0.0);
//    glTexCoord2f(0.0, coordY);
//    glVertex3f(-offset, size.height, 0.0);
//    glEnd();
//    glDisable(GL_TEXTURE_2D);
//    
//    [nsContext flushBuffer];
//    
//    currentScreenIndex ^= 1;
//    
//    CGLUnlockContext(cglContext);
//}

@end
