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

#import "FXAppDelegate.h"
#import "FXLoader.h"
#import "FXROMSet.h"
#import "FXZipArchive.h"

#include "burner.h"

@interface FXRunLoop ()

- (BOOL)initializeDriver:(NSError **)error;
- (BOOL)cleanupDriver;

- (UInt32)ticks;
- (BOOL)idle;
- (BOOL)runFrame:(BOOL)draw
           pause:(BOOL)pause;
- (void)reset;

- (UInt32)loadROMOfDriver:(int)driverId
                    index:(int)romIndex
               intoBuffer:(void *)buffer
             bufferLength:(int *)length;

@end

static int cocoaGetNextSound(int draw);

@implementation FXRunLoop

#pragma mark - init

- (instancetype)initWithDriverId:(int)driverId
{
    if (self = [super init]) {
        self->zipArchiveDictionary = [[NSMutableDictionary alloc] init];
        [self setDriverId:driverId];
    }
    
    return self;
}

- (void)dealloc
{
    // This should close any open files
    [self->zipArchiveDictionary removeAllObjects];
}

#pragma mark - Methods

- (void)reset
{
    // Reset the speed throttling code
    self->lastTick = 0;
    self->fraction = 0;
    self->lastTick = [self ticks];
    self->previouslyDrawn = NO;
    self->previouslyPaused = NO;
}

#pragma mark - Driver init

- (BOOL)initializeDriver:(NSError **)error
{
    int driverId = [self driverId];
    
	InputInit();
    
	bBurnUseASMCPUEmulation = 0;
 	bCheatsAllowed = false;
    
#ifdef DEBUG
    NSLog(@"Initializing driver...");
#endif
    
	AudSoundInit();
    
    nBurnDrvActive = driverId;
	nBurnDrvSelect[0] = driverId;
    
	nMaxPlayers = BurnDrvGetMaxPlayers();
	GameInpInit();
    
	ConfigGameLoad(true);
	InputMake(true);
    
	GameInpDefault();
    
    // Audit the driver - it'll be needed during the loading phase
    FXLoader *loader = [[FXLoader alloc] init];
    driverAudit = [loader auditDriver:driverId
                                error:error];
    
    BurnExtLoadRom = cocoaLoadROMCallback;
    
    id<FXRunLoopDelegate> delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(loadingDidStart)]) {
        [delegate loadingDidStart];
    }
    
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"runLoop/loadingDidStart");
#endif
    
    BOOL initializationFailed = NO;
	if (BurnDrvInit()) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"org.akop.fbx.Emulation"
                                       code:FXErrorDriverInitialization
                                   userInfo:@{ NSLocalizedDescriptionKey : @"Error initializing core driver" }];
        }
        
		BurnDrvExit();
        initializationFailed = YES;
	}
    
    if ([delegate respondsToSelector:@selector(loadingDidEnd)]) {
        [delegate loadingDidEnd];
    }
    
    // Close any open archives
    [zipArchiveDictionary removeAllObjects];
    
#ifdef DEBUG
    NSLog(@"runLoop/loadingDidEnd (%.02fs)",
          [[NSDate date] timeIntervalSinceDate:started]);
#endif
    
    if (initializationFailed) {
        return NO;
    }
    
	bDrvOkay = 1;
	nBurnLayer = 0xFF;
    
    return YES;
}

- (BOOL)cleanupDriver
{
	if (bDrvOkay) {
        InputExit();
		VidExit();
        AudSoundExit();
        
		if (nBurnDrvSelect[0] < nBurnDrvCount) {
			ConfigGameSave(bSaveInputs);
            
			GameInpExit();
			BurnDrvExit();
		}
	}
    
	BurnExtLoadRom = NULL;
	bDrvOkay = 0;
    
	if (bAudOkay) {
        // Write silence into the sound buffer
		memset(nAudNextSound, 0, nAudSegLen << 2);
	}
    
	nBurnDrvSelect[0] = ~0U;			// no driver selected
    
#ifdef DEBUG
    NSLog(@"Driver cleaned up");
#endif
    
	return YES;
}

#pragma mark - Emulation loop

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
	} else {
		pBurnDraw = NULL;
		BurnDrvFrame();
	}
    
	self->previouslyPaused = paused;
	self->previouslyDrawn = draw;
    
    return YES;
}

- (BOOL)idle
{
    [self ticks];
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
    
    if (count > 100) {
        // Limit frame skipping
        count = 100;
    }
    
    if (bRunPause) {
        [self runFrame:YES pause:YES];
        return YES;
    }
    
    for (int i = count / 10; i > 0; i--) {
        // Mid-frames
        [self runFrame:YES pause:NO];
    }
    
    [self runFrame:YES pause:NO];
    
    return YES;
}

- (void)main
{
    NSError *error = NULL;
    
    if (![self initializeDriver:&error]) {
#ifdef DEBUG
        NSLog(@"Driver did not initialize - exiting run loop");
#endif
        return;
    }
    
    NSLog(@"runLoop/start");
    
    if (!bVidOkay) {
        VidInit();
    }
    
    // FIXME
	AudSetCallback(cocoaGetNextSound);
	AudSoundPlay();
    
    [self reset];
    
    while (![self isCancelled]) {
        [self idle];
    }
    
	AudSoundStop();
    
    NSLog(@"runLoop/stop");
    
    [self cleanupDriver];
}

- (void)cancel
{
    [super cancel];
    
#ifdef DEBUG
    NSLog(@"Waiting for run loop to exit...");
#endif
    for (;;) {
        if ([self isFinished]) {
            break;
        }
    }
#ifdef DEBUG
    NSLog(@"Run loop terminated.");
#endif
}

#pragma mark - Private methods

- (UInt32)ticks
{
    return (UInt32)([[NSDate date] timeIntervalSince1970] * 1000.0);
}

- (UInt32)loadROMOfDriver:(int)driverId
                    index:(int)romIndex
               intoBuffer:(void *)buffer
             bufferLength:(int *)length
{
    if (![FXROMSet isDriverIdValid:driverId]) {
        return 1;
    }
    
    struct BurnRomInfo info;
    if (![FXROMSet romInfoOfSetWithDriverId:driverId
                                   romIndex:romIndex
                                    romInfo:&info]) {
        return 1;
    }
    
    FXROMAudit *romAudit = [driverAudit ROMAuditByNeededCRC:info.nCrc];
    if (romAudit == nil || [romAudit status] == FXROMAuditMissing) {
        return 1;
    }
    
    NSString *path = [romAudit containerPath];
    NSUInteger uncompressedLength = [romAudit lengthFound];
    NSUInteger foundCRC = [romAudit CRCFound];
    
    NSError *error = nil;
    
    FXZipArchive *archive = [zipArchiveDictionary objectForKey:path];
    if (archive == nil) {
        FXZipArchive *openArchive = [[FXZipArchive alloc] initWithPath:path
                                                                 error:&error];
        
        if (error != nil) {
            return 1;
        }
        
        // Cache the archive for duration of the loading process
        archive = openArchive;
        [zipArchiveDictionary setObject:archive
                                 forKey:path];
    }
    
    UInt32 bytesRead = [archive readFileWithCRC:foundCRC
                                     intoBuffer:buffer
                                   bufferLength:uncompressedLength
                                          error:&error];
    
    if (error != nil) {
        if (bytesRead > -1) {
            if (length != NULL) {
                *length = bytesRead;
            }
            
            return 2;
        }
        
        return 1;
    }
    
    if (length != NULL) {
        *length = bytesRead;
    }
    
#ifdef DEBUG
    NSLog(@"%d/%d found in %@, read %d bytes",
          driverId, romIndex, path, bytesRead);
#endif
    
    return 0;
}

@end

#pragma mark - Core callbacks

// FIXME: move into audio code
static int cocoaGetNextSound(int draw)
{
	if (nAudNextSound == NULL) {
		return 1;
	}
    
    FXRunLoop *runLoop = [[[FXAppDelegate sharedInstance] emulator] runLoop];
    
	if (bRunPause) {
        [runLoop runFrame:draw pause:YES];
		return 0;
	}
    
	// Render frame with sound
	pBurnSoundOut = nAudNextSound;
    [runLoop runFrame:draw pause:NO];
    
	return 0;
}

int cocoaLoadROMCallback(unsigned char *Dest, int *pnWrote, int i)
{
    FXRunLoop *runLoop = [[[FXAppDelegate sharedInstance] emulator] runLoop];
    return [runLoop loadROMOfDriver:nBurnDrvActive
                              index:i
                         intoBuffer:Dest
                       bufferLength:pnWrote];
}
