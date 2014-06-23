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
#import <Foundation/Foundation.h>
#include <AudioUnit/AudioUnit.h>

@interface FXAudioEngine : NSObject
{
    BOOL isPaused;
    BOOL isReady;
    
    UInt32 readPtr;
    UInt32 writePtr;
    UInt32 bufferMask;
    UInt32 bufferSize;
    UInt32 oldLen;
    UInt32 bytesPerSample;
    UInt32 skipCount;
    UInt8* buffer;
    
	void *__buffer;
	UInt32 __bufferOffset;
	UInt32 __bufferSize;
    
    AudioUnit outputAudioUnit;
}

- (id)initWithSampleRate:(NSUInteger)sampleRate
                channels:(NSUInteger)channels
              bufferSize:(NSUInteger)aBufferSize
          bitsPerChannel:(UInt32)bitsPerChannel;

- (void)mixSoundFromBuffer:(SInt16 *)mixBuffer
                     bytes:(UInt32)bytes;

- (void)pause;
- (void)resume;

@end
