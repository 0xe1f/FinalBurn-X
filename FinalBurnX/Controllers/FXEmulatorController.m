//
//  FXEmulatorController.m
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/17/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "FXEmulatorController.h"

#import "AKEmulator.h"
#import "FXInput.h"

@interface FXEmulatorController ()

- (void)emulatorThreadMethod:(id)obj;
- (void)windowKeyDidChange:(BOOL)isKey;

@end

@implementation FXEmulatorController

@synthesize emulator = _emulator;
@synthesize thread = _thread;
@synthesize input = _input;

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setEmulator:[[AKEmulator alloc] init]];
        [self setInput:[[FXInput alloc] init]];

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
    [self setInput:nil];
}

- (void)awakeFromNib
{
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

#pragma mark - ...

- (void)emulatorThreadMethod:(id)obj
{
    [[self emulator] runROM:@"sfa3u"
                      error:NULL];
}

#pragma mark - etc...

- (void)windowKeyDidChange:(BOOL)isKey
{
    [[self input] setFocus:isKey];
}

@end
