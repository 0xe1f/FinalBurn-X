/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014-2016 Akop Karapetyan
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

#include "burner.h"

#import "FXEmulator.h"

@implementation FXVideo
{
	unsigned char *_buffer;
	int _bufferSize;
	NSMutableData *_screenBuffer;
}

#pragma mark - Init and dealloc

- (instancetype) init
{
    if (self = [super init]) {
		self->_screenBuffer = nil;
		self->_ready = NO;
		self->_buffer = NULL;
    }

    return self;
}

- (void) dealloc
{
    [self cleanup];
}

#pragma mark - Core callbacks

- (BOOL) initCore
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
	
    self->_bytesPerPixel = nVidImageBPP;
    self->_bufferWidth = gameWidth;
    self->_bufferHeight = gameHeight;
	
    self->_bufferSize = self->_bufferWidth * self->_bufferHeight * nVidImageBPP;
    @synchronized(self) {
        free(self->_buffer);
        self->_buffer = (unsigned char *) malloc(self->_bufferSize);
		self->_screenBuffer = [NSMutableData dataWithLength:self->_bufferSize];
    }
    
    if (self->_buffer == NULL) {
        return NO;
    }
	
	nBurnBpp = nVidImageBPP;
	nBurnPitch = nVidImagePitch;
    pVidImage = self->_buffer;
    
    memset(self->_buffer, 0, self->_bufferSize);
    
    int textureWidth;
    int textureHeight;
    self->_isRotated = rotationMode & 1;
    
    if (!self->_isRotated) {
        textureWidth = self->_bufferWidth;
        textureHeight = self->_bufferHeight;
    } else {
        textureWidth = self->_bufferHeight;
        textureHeight = self->_bufferWidth;
    }
	
	self->_ready = YES;
	
    return YES;
}

- (BOOL) renderFrame:(BOOL) redraw
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

- (BOOL) renderToSurface:(BOOL) validate
{
	[self->_screenBuffer replaceBytesInRange:NSMakeRange(0, self->_bufferSize)
								   withBytes:self->_buffer];
	
    return YES;
}

#pragma mark - Etc

- (void) cleanup
{
    @synchronized(self) {
        free(self->_buffer);
        self->_buffer = NULL;
    }
}

#pragma mark - Public

- (NSData *) screenBuffer
{
	return [self->_screenBuffer copy];
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaVideoInit()
{
    FXVideo *video = [[FXEmulator sharedInstance] video];
    return [video initCore] ? 0 : 1;
}

static int cocoaVideoExit()
{
	FXVideo *video = [[FXEmulator sharedInstance] video];
    [video cleanup];
    
    return 0;
}

static int cocoaVideoFrame(bool redraw)
{
	FXVideo *video = [[FXEmulator sharedInstance] video];
    return [video renderFrame:redraw] ? 0 : 1;
}

static int cocoaVideoPaint(int validate)
{
	FXVideo *video = [[FXEmulator sharedInstance] video];
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
