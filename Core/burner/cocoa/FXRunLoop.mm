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
#import "FXRunLoop.h"

#import "AKAppDelegate.h"

#include "burner.h"

@interface FXRunLoop ()

- (UInt32)ticks;
- (BOOL)idle;
- (BOOL)runFrame:(BOOL)draw
           pause:(BOOL)pause;
- (void)reset;

@end

static int cocoaGetNextSound(int draw);

@implementation FXRunLoop

- (void)reset
{
    // Reset the speed throttling code
    self->start.tv_sec = -1;
    self->start.tv_usec = -1;
    self->lastTick = 0;
    self->stop = NO;
    self->fraction = 0;
    self->lastTick = [self ticks];
    self->previouslyDrawn = NO;
    self->previouslyPaused = NO;
}

- (BOOL)runFrame:(BOOL)draw
           pause:(BOOL)paused
{
    if (self->previouslyDrawn && !paused) {
        VidPaint(0);
    }
    
	if (!bDrvOkay) {
		return NO;
	}
    
	if (paused) {
        InputMake(false);
		if (paused != self->previouslyPaused) {
			VidPaint(2);
		}
	} else {
		nFramesEmulated++;
		nCurrentFrame++;
		InputMake(true);
	}
    
	if (draw) {
		nFramesRendered++;
		if (VidFrame()) {
			AudBlankSound();
		}
	} else {								// frame skipping
		pBurnDraw = NULL;
		BurnDrvFrame();
	}
    
	self->previouslyPaused = paused;
	self->previouslyDrawn = draw;
    
    return YES;
}

- (BOOL)idle
{
    if (bAudPlaying) {
        // Run with sound
        AudSoundCheck();
        return YES;
    }
    
    // Run without sound
    UInt32 time = [self ticks] - self->lastTick;
    int count = (time * nAppVirtualFps - self->fraction) / 100000;
    if (count <= 0) {
        [NSThread sleepForTimeInterval:.003];
        return YES;
    }
    
    self->fraction += count * 100000;
    self->lastTick += self->fraction / nAppVirtualFps;
    self->fraction %= nAppVirtualFps;
    
    if (count > 100) {						// Limit frame skipping
        count = 100;
    }
    
    if (bRunPause) {
        [self runFrame:YES pause:YES];
        return YES;
    }
    
    for (int i = count / 10; i > 0; i--) {	// Mid-frames
        [self runFrame:YES pause:NO];
    }
    
    [self runFrame:YES pause:NO];
    
    return YES;
}

- (BOOL)run
{
    @synchronized(self) {
        if (self->running) {
            return NO;
        }
        
        self->running = YES;
    }
    
    NSLog(@"runLoop/start");
    
    if (!bVidOkay) {
        VidInit();
    }
    
    // FIXME
	AudSetCallback(cocoaGetNextSound);
	AudSoundPlay();
    
    [self reset];
    
    while (!self->stop) {
        [self idle];
    }
    
	AudSoundStop();
    
    @synchronized(self) {
        self->running = NO;
    }
    
    NSLog(@"runLoop/stop");
    
    return YES;
}

- (BOOL)stop
{
    self->stop = YES;
    
    for (;;) {
        @synchronized(self) {
            if (!self->running) {
                break;
            }
        }
    }
    
    return YES;
}

#pragma mark - Etc

- (UInt32)ticks
{
    if (self->start.tv_sec < 0) {
        gettimeofday(&self->start, NULL);
    }
    
	UInt32 ticks;
	struct timeval now;
	gettimeofday(&now, NULL);
	ticks = (UInt32)(now.tv_sec - self->start.tv_sec) * 1000 +
        (UInt32)(now.tv_usec - self->start.tv_usec) / 1000;
    
    return ticks;
}

@end

#pragma mark - Core callbacks

// FIXME: move into audio code
static int cocoaGetNextSound(int draw)
{
	if (nAudNextSound == NULL) {
		return 1;
	}
    
    FXRunLoop *runLoop = [[[AKAppDelegate sharedInstance] emulator] runLoop];
    
	if (bRunPause) {
        [runLoop runFrame:draw pause:YES];
		return 0;
	}
    
	// Render frame with sound
	pBurnSoundOut = nAudNextSound;
    [runLoop runFrame:draw pause:NO];
    
	return 0;
}
