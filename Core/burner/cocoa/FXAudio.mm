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
#import "FXAudio.h"

#import "FXAppDelegate.h"

#include "burner.h"

static int cocoaGetNextSoundFiller(int draw);

@interface FXAudio ()

- (void)cleanup;

@end

@implementation FXAudio
{
	int (*audioCallback)(int);
	int soundFps;
	int soundLoopLength;
	short *soundBuffer;
	int playPosition;
	int fillSegment;
	NSInteger _volume;
	BOOL needsCleanup;
}

#pragma mark - Init and dealloc

- (instancetype) init
{
    if (self = [super init]) {
		_volume = 100;
		needsCleanup = NO;
    }

    return self;
}

- (void)dealloc
{
    [self cleanup];
}

#pragma mark - Public

- (void) setVolume:(NSInteger) volume
{
	NSLog(@"audio/setVolume: %ld", volume);

	_volume = volume;
	[_audioEngine setVolume:volume];
}

#pragma mark - Core callbacks

- (BOOL)initCore
{
    NSLog(@"audio/init");
    
    int sampleRate = 44100;
    
    self->audioCallback = NULL;
	self->soundFps = nAppVirtualFps;
    nAudSegLen = (sampleRate * 100 + (self->soundFps / 2)) / self->soundFps;
    self->soundLoopLength = (nAudSegLen * nAudSegCount) * 4;
    
    int bufferSize = 64;
    for (; bufferSize < (nAudSegLen >> 1); bufferSize *= 2);
    
    self->soundBuffer = (short *)calloc(self->soundLoopLength, 1);
    if (self->soundBuffer == NULL) {
        [self cleanup];
        return NO;
    }

    nAudNextSound = (short *)calloc(nAudSegLen << 2, 1);
    if (nAudNextSound == NULL) {
        return NO;
    }

    needsCleanup = YES;
    self->playPosition = 0;
    self->fillSegment = nAudSegCount - 1;
    
    [self setAudioEngine:[[FXAudioEngine alloc] initWithSampleRate:sampleRate
                                                          channels:2
                                                           samples:bufferSize
                                                    bitsPerChannel:16]];
	[_audioEngine setVolume:_volume];
    
    nBurnSoundRate = sampleRate;
    nBurnSoundLen = nAudSegLen;

    [[self audioEngine] setDelegate:self];

    return YES;
}

- (void)exitCore
{
    NSLog(@"audio/exit");
    
    [self cleanup];
    [self setAudioEngine:nil];
}

- (void)setCallback:(int(*)(int))callback
{
    NSLog(@"audio/setCallback");
    
    if (callback == NULL) {
        self->audioCallback = cocoaGetNextSoundFiller;
    } else {
        self->audioCallback = callback;
    }
}

- (BOOL)isPaused
{
    return !bAudPlaying;
}

- (void)setPaused:(BOOL)paused
{
    if (paused != [self isPaused]) {
        if (!paused) {
            NSLog(@"audio/setPaused:NO");
            [[self audioEngine] resume];
            bAudPlaying = 1;
        } else {
            NSLog(@"audio/setPaused:YES");
            [[self audioEngine] pause];
            bAudPlaying = 0;
        }
    }
}

- (BOOL)clear
{
    NSLog(@"audio/clear");
    
    if (nAudNextSound) {
        memset(nAudNextSound, 0, nAudSegLen << 2);
    }
    
    return YES;
}

#pragma mark - FXAudioDelegate

- (void)mixSoundFromBuffer:(SInt16 *)stream
                     bytes:(UInt32)len
{
    int end = self->playPosition + len;
	if (end > self->soundLoopLength) {
		memcpy(stream, (UInt8 *)self->soundBuffer + self->playPosition, self->soundLoopLength - self->playPosition);
		end -= self->soundLoopLength;
		memcpy((UInt8 *)stream + self->soundLoopLength - self->playPosition, (UInt8 *)self->soundBuffer, end);
		self->playPosition = end;
	} else {
		memcpy(stream, (UInt8 *)self->soundBuffer + self->playPosition, len);
		self->playPosition = end;
        
		if (self->playPosition == self->soundLoopLength) {
			self->playPosition = 0;
		}
	}
}

#define WRAP_INC(x) { x++; if (x >= nAudSegCount) x = 0; }

- (BOOL)checkAudio
{
    if (!bAudPlaying) {
        return YES;
    }
    
    // Since the sound buffer is smaller than a segment, only fill
    // the buffer up to the start of the currently playing segment
    int playSegment = self->playPosition / (nAudSegLen << 2) - 1;
    if (playSegment >= nAudSegCount) {
        playSegment -= nAudSegCount;
    }
    if (playSegment < 0) {
        playSegment = nAudSegCount - 1;
    }
    
    if (self->fillSegment == playSegment) {
        [NSThread sleepForTimeInterval:.001];
        return YES;
    }
    
    // work out which seg we will fill next
    int followingSegment = self->fillSegment;
    WRAP_INC(followingSegment);
    while (self->fillSegment != playSegment) {
        int draw = (followingSegment == playSegment);
        self->audioCallback(draw);
        
        memcpy((char *)self->soundBuffer + self->fillSegment * (nAudSegLen << 2),
               nAudNextSound, nAudSegLen << 2);
        
        self->fillSegment = followingSegment;
        WRAP_INC(followingSegment);
    }
    
    return YES;
}

#pragma mark - Etc

- (void)cleanup
{
    free(self->soundBuffer);
    self->soundBuffer = NULL;
    if (needsCleanup) {
        free(nAudNextSound);
        nAudNextSound = NULL;
    }
    needsCleanup = NO;
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaGetNextSoundFiller(int draw)
{
	if (nAudNextSound == NULL) {
		return 1;
	}
    
    // Write silence into buffer
	memset(nAudNextSound, 0, nAudSegLen << 2);
	return 0;
}

static int cocoaAudioBlankSound()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    return [audio clear] ? 0 : 1;
}

static int cocoaAudioCheck()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    return [audio checkAudio] ? 0 : 1;
}

static int cocoaAudioInit()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    return [audio initCore] ? 0 : 1;
}

static int cocoaAudioSetCallback(int (*callback)(int))
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    [audio setCallback:callback];
    
	return 0;
}

static int cocoaAudioPlay()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    [audio setPaused:NO];
    return 0;
}

static int cocoaAudioStop()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    [audio setPaused:YES];
    return 0;
}

static int cocoaAudioExit()
{
    FXAudio *audio = [[[FXAppDelegate sharedInstance] emulator] audio];
    [audio exitCore];
    
    return 0;
}

static int cocoaAudioSetVolume()
{
	return 1;
}

static int cocoaAudioGetSettings(InterfaceInfo *info)
{
	return 0;
}

struct AudOut AudOutCocoa = {
    cocoaAudioBlankSound,
    cocoaAudioCheck,
    cocoaAudioInit,
    cocoaAudioSetCallback,
    cocoaAudioPlay,
    cocoaAudioStop,
    cocoaAudioExit,
    cocoaAudioSetVolume,
    cocoaAudioGetSettings,
    "Cocoa audio output"
};
