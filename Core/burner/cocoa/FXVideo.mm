/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
 **
 ** Licensed under the Apache License, Version 2.0 (the "License");
 ** you may not use this file except in compliance with the License.
 ** You may obtain a copy of the License at
 **
 **     http://www.apache.org/licenses/LICENSE-2.0
 **
 ** Unless required by applicable law or agreed to in writing, software
 ** distributed under the License is distributed on an "AS IS" BASIS,
 ** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 ** See the License for the specific language governing permissions and
 ** limitations under the License.
 **
 ******************************************************************************
 */
#import "FXVideo.h"

#import "FXAppDelegate.h"

#include "burner.h"

@interface FXVideo ()

- (void)cleanup;

@end

@implementation FXVideo
{
	unsigned char *screenBuffer;
	int bufferWidth;
	int bufferHeight;
	int bufferBytesPerPixel;
}

#pragma mark - Init and dealloc

- (instancetype)init
{
    if (self = [super init]) {
        self->screenBuffer = NULL;
    }

    return self;
}

- (void)dealloc
{
    [self cleanup];
	
	_delegate = nil;
}

#pragma mark - Core callbacks

- (BOOL)initCore
{
    NSLog(@"video/init");
    
    int gameWidth;
    int gameHeight;
    int rotationMode = 0;
    
    BurnDrvGetVisibleSize(&gameWidth, &gameHeight);
    
    if (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL) {
        rotationMode |= 1;
    }
    
    if (BurnDrvGetFlags() & BDF_ORIENTATION_FLIPPED) {
        rotationMode ^= 2;
    }
    
    nVidImageWidth = gameWidth;
    nVidImageHeight = gameHeight;
    nVidImageDepth = 24;
	nVidImageBPP = 3;
	if (!rotationMode) {
        nVidImagePitch = nVidImageWidth * nVidImageBPP;
	} else {
        nVidImagePitch = nVidImageHeight * nVidImageBPP;
	}
    
	SetBurnHighCol(nVidImageDepth);
    
    self->bufferBytesPerPixel = nVidImageBPP;
    self->bufferWidth = gameWidth;
    self->bufferHeight = gameHeight;
    
    int bufSize = self->bufferWidth * self->bufferHeight * nVidImageBPP;
    @synchronized(self) {
        free(self->screenBuffer);
        self->screenBuffer = (unsigned char *)malloc(bufSize);
    }
    
    if (self->screenBuffer == NULL) {
        return NO;
    }
    
	nBurnBpp = nVidImageBPP;
	nBurnPitch = nVidImagePitch;
    pVidImage = self->screenBuffer;
    
    memset(self->screenBuffer, 0, bufSize);
    
    int textureWidth;
    int textureHeight;
    BOOL isRotated = rotationMode & 1;
    
    if (!isRotated) {
        textureWidth = self->bufferWidth;
        textureHeight = self->bufferHeight;
    } else {
        textureWidth = self->bufferHeight;
        textureHeight = self->bufferWidth;
    }
    
    NSSize screenSize = NSMakeSize((CGFloat)self->bufferWidth,
                                   (CGFloat)self->bufferHeight);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		id<FXVideoDelegate> delegate = [self delegate];
		if ([delegate respondsToSelector:@selector(initTextureOfWidth:height:isRotated:bytesPerPixel:)]) {
			[delegate initTextureOfWidth:textureWidth
								  height:textureHeight
							   isRotated:isRotated
						   bytesPerPixel:self->bufferBytesPerPixel];
		}
		
		if ([delegate respondsToSelector:@selector(screenSizeDidChange:)]) {
			[delegate screenSizeDidChange:screenSize];
		}
	});
    
    return YES;
}

- (void)exitCore
{
    NSLog(@"video/exit");
    
    [self cleanup];
}

- (BOOL)renderFrame:(BOOL)redraw
{
	if (pVidImage == NULL) {
		return NO;
	}
    
    if (redraw) {
        if (BurnDrvRedraw()) {
            BurnDrvFrame();
        }
    } else {
        BurnDrvFrame();
	}
    
	return YES;
}

- (BOOL)renderToSurface:(BOOL)validate
{
    id<FXVideoDelegate> delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(renderFrame:)]) {
        [delegate renderFrame:self->screenBuffer];
    }
    
    return YES;
}

#pragma mark - Etc

- (void)cleanup
{
    @synchronized(self) {
        free(self->screenBuffer);
        self->screenBuffer = NULL;
    }
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaVideoInit()
{
    FXVideo *video = [[[FXAppDelegate sharedInstance] emulator] video];
    return [video initCore] ? 0 : 1;
}

static int cocoaVideoExit()
{
    FXVideo *video = [[[FXAppDelegate sharedInstance] emulator] video];
    [video exitCore];
    
    return 0;
}

static int cocoaVideoFrame(bool redraw)
{
    FXVideo *video = [[[FXAppDelegate sharedInstance] emulator] video];
    return [video renderFrame:redraw] ? 0 : 1;
}

static int cocoaVideoPaint(int validate)
{
    FXVideo *video = [[[FXAppDelegate sharedInstance] emulator] video];
    return [video renderToSurface:(validate & 2)] ? 0 : 1;
}

static int cocoaVideoScale(RECT* , int, int)
{
	return 0;
}

static int cocoaVideoGetSettings(InterfaceInfo *info)
{
	return 0;
}

struct VidOut VidOutCocoa = {
    cocoaVideoInit,
    cocoaVideoExit,
    cocoaVideoFrame,
    cocoaVideoPaint,
    cocoaVideoScale,
    cocoaVideoGetSettings,
    _T("Cocoa Video"),
};
