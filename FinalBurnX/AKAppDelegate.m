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

static AKAppDelegate *instance = nil;

- (instancetype)init
{
    if (self = [super init]) {
        instance = self;
    }
    
    return self;
}

- (void)dealloc
{
    [self setEmulator:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setEmulator:[[AKEmulatorController alloc] init]];
    [[self emulator] showWindow:self];
}

+ (AKAppDelegate *)instance
{
    return instance;
}

@end
