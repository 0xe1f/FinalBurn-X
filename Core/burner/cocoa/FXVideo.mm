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
#include "vid_softfx.h"
#include "vid_support.h"

@interface FXVideo ()

- (void)cleanup;
- (BOOL)initBuffersOfWidth:(int)width
                    height:(int)height
                 pixelSize:(int)bytesPerPixel;
+ (int)powerOfTwoClosestTo:(int)number;

@end

@implementation FXVideo

@synthesize delegate = _delegate;

#pragma mark - Init and dealloc

- (instancetype)init
{
    if (self = [super init]) {
        for (int i = 0; i < 2; i++) {
            self->buffers[i] = NULL;
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
    NSLog(@"initVideoCore");

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
    
	if (rotationMode & 1) {
		nVidImageWidth = gameHeight;
		nVidImageHeight = gameWidth;
	} else {
		nVidImageWidth = gameWidth;
		nVidImageHeight = gameHeight;
	}
    
    nVidImageDepth = 15; //32;
	nVidImageBPP = 2; //4;
	nBurnBpp = nVidImageBPP;
    bVidScanlines = 0;
    
	SetBurnHighCol(nVidImageDepth);
	if (VidSAllocVidImage()) {
        [self cleanup];
        return NO;
	}
    
    if (![self initBuffersOfWidth:gameWidth
                           height:gameHeight
                        pixelSize:nVidImageBPP]) {
        [self cleanup];
        return NO;
    }
    
	if (VidSoftFXInit(0, rotationMode) != 0) {
        [self cleanup];
        return NO;
    }
    
    return YES;
}

- (void)exitCore
{
    NSLog(@"exitVideoCore");
    
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
    
    VidFilterApplyEffect((unsigned char *)self->buffers[0], self->bufferPitch);
    
	return YES;
}

- (BOOL)renderToSurface:(BOOL)validate
{
    if (self->_delegate) {
        [self->_delegate renderFrame:self->buffers[0]
                               width:self->bufferWidth
                              height:self->bufferHeight
                               pitch:self->bufferPitch];
    }
    
    return YES;
}

#pragma mark - Etc

- (BOOL)initBuffersOfWidth:(int)width
                    height:(int)height
                 pixelSize:(int)bytesPerPixel
{
    self->bufferBytesPerPixel = bytesPerPixel;
    self->bufferPitch = [FXVideo powerOfTwoClosestTo:width];
    self->bufferWidth = width;
    self->bufferHeight = height;
    
    for (int i = 0; i < 2; i++) {
        if (self->buffers[i] != NULL) {
            free(self->buffers[i]);
            self->buffers[i] = NULL;
        }
        
        int bufSize = self->bufferPitch * height * bytesPerPixel;
        if ((self->buffers[i] = (unsigned char *)malloc(bufSize)) == NULL) {
            break;
        }
    }
    
    return self->buffers[0] != NULL && self->buffers[1] != NULL;
}

+ (int)powerOfTwoClosestTo:(int)number
{
    int rv = 1;
    while (rv < number) rv *= 2;
    return rv;
}

- (void)cleanup
{
    for (int i = 0; i < 2; i++) {
        if (self->buffers[i] != NULL) {
            free(self->buffers[i]);
            self->buffers[i] = NULL;
        }
    }

	VidSFreeVidImage();
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
