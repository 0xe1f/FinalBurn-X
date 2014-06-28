/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 **
 ******************************************************************************
 */
#import "FXVideo.h"

#import "AKAppDelegate.h"

#include "burner.h"

@interface FXVideo ()

- (void)cleanup;

@end

@implementation FXVideo

#pragma mark - Init and dealloc

- (instancetype)init
{
    if (self = [super init]) {
        for (int i = 0; i < 2; i++) {
            self->screenBuffer = NULL;
        }
    }

    return self;
}

- (void)dealloc
{
    [self cleanup];
    
    [self setDelegate:nil];
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
        if (nVidRotationAdjust & 1) {
            int n = gameWidth;
            gameWidth = gameHeight;
            gameHeight = n;
            rotationMode |= (nVidRotationAdjust & 2);
        } else {
            rotationMode |= 1;
        }

		if (BurnDrvGetFlags() & BDF_ORIENTATION_FLIPPED) {
			rotationMode ^= 2;
		}
    }
    
    nVidImageDepth = 24;
	nVidImageBPP = 3;
	nBurnBpp = nVidImageBPP;
    bVidScanlines = 0;
    
	if (rotationMode & 1) {
		nVidImageWidth = gameHeight;
		nVidImageHeight = gameWidth;
        nVidImagePitch = nVidImageHeight * nVidImageBPP;
	} else {
		nVidImageWidth = gameWidth;
		nVidImageHeight = gameHeight;
        nVidImagePitch = nVidImageWidth * nVidImageBPP;
	}
    
	SetBurnHighCol(nVidImageDepth);
    
    self->bufferBytesPerPixel = nVidImageBPP;
    self->bufferWidth = gameWidth;
    self->bufferHeight = gameHeight;
    
    free(self->screenBuffer);
    self->screenBuffer = NULL;
    
    int bufSize = self->bufferWidth * self->bufferHeight * nVidImageBPP;
    self->screenBuffer = (unsigned char *)malloc(bufSize);
    
    if (self->screenBuffer == NULL) {
        return NO;
    }
    
	nBurnPitch = nVidImagePitch;
    
    memset(self->screenBuffer, 0, bufSize);
    
    free(pVidImage);
    pVidImage = self->screenBuffer;
    
    [self->_delegate initTextureOfWidth:self->bufferWidth
                                 height:self->bufferHeight
                          bytesPerPixel:self->bufferBytesPerPixel];
    
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
    [self->_delegate renderFrame:self->screenBuffer
                           width:self->bufferWidth
                          height:self->bufferHeight];
    
    return YES;
}

#pragma mark - Etc

- (void)cleanup
{
    free(self->screenBuffer);
    self->screenBuffer = NULL;
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaVideoInit()
{
    FXVideo *video = [[[AKAppDelegate sharedInstance] emulator] video];
    return [video initCore] ? 0 : 1;
}

static int cocoaVideoExit()
{
    FXVideo *video = [[[AKAppDelegate sharedInstance] emulator] video];
    [video exitCore];
    
    return 0;
}

static int cocoaVideoFrame(bool redraw)
{
    FXVideo *video = [[[AKAppDelegate sharedInstance] emulator] video];
    return [video renderFrame:redraw] ? 0 : 1;
}

static int cocoaVideoPaint(int validate)
{
    FXVideo *video = [[[AKAppDelegate sharedInstance] emulator] video];
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
    "Cocoa Video",
};
