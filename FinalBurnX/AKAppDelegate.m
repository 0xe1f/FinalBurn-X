//
//  AKAppDelegate.m
//  FinalBurn X
//
//  Created by Akop Karapetyan on 6/10/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "AKAppDelegate.h"

#import "AKEmulator.h"

@implementation AKAppDelegate

@synthesize emulator = _emulator;

static AKAppDelegate *sharedInstance = nil;

- (instancetype)init
{
    if (self = [super init]) {
        sharedInstance = self;
    }
    
    return self;
}

- (void)dealloc
{
    [self setEmulator:nil];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [self setEmulator:[[FXEmulatorController alloc] init]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[self emulator] showWindow:self];
}

+ (AKAppDelegate *)sharedInstance
{
    return sharedInstance;
}

@end
