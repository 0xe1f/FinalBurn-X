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
#import "FXEmulatorController.h"

#import "AKEmulator.h"
#import "FXInput.h"
#import "FXVideo.h"
#import "FXAudio.h"
#import "FXAudioEngine.h"
#import "FXRunLoop.h"

@interface FXEmulatorController ()

- (void)emulatorThreadMethod:(id)obj;
- (void)windowKeyDidChange:(BOOL)isKey;

@end

@implementation FXEmulatorController

@synthesize emulator = _emulator;
@synthesize thread = _thread;
@synthesize input = _input;
@synthesize video = _video;
@synthesize audio = _audio;
@synthesize runLoop = _runLoop;

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setInput:[[FXInput alloc] init]];
        [self setVideo:[[FXVideo alloc] init]];
        [self setAudio:[[FXAudio alloc] init]];
        [self setRunLoop:[[FXRunLoop alloc] init]];
        
        [self setEmulator:[[AKEmulator alloc] init]];
        [self setThread:[[NSThread alloc] initWithTarget:self
                                                selector:@selector(emulatorThreadMethod:)
                                                  object:nil]];
    }
    
    return self;
}

- (void)dealloc
{
    [self setThread:nil];
    [self setEmulator:nil];
}

- (void)awakeFromNib
{
    [[self video] setDelegate:screen];
    
    [[self thread] start];
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [self windowKeyDidChange:YES];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self windowKeyDidChange:NO];
}

- (void)keyDown:(NSEvent *)theEvent
{
    // Suppress the beeps
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_runLoop stop];
}

#pragma mark - ...

- (void)emulatorThreadMethod:(id)obj
{
    [[self emulator] runROM:@"sfiii"
                      error:NULL];
    
    [self setVideo:nil];
    [self setAudio:nil];
    [self setInput:nil];
    [self setRunLoop:nil];
}

#pragma mark - etc...

- (void)windowKeyDidChange:(BOOL)isKey
{
    [[self input] setFocus:isKey];
}

@end
