//
//  AKEmulatorController.m
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/17/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "AKEmulatorController.h"

#import "AKEmulator.h"

@interface AKEmulatorController ()

- (void)emulatorThreadMethod:(id)obj;

@end

@implementation AKEmulatorController

@synthesize emulator = _emulator;
@synthesize thread = _thread;

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setThread:[[NSThread alloc] initWithTarget:self
                                                selector:@selector(emulatorThreadMethod:)
                                                  object:nil]];
    }
    
    return self;
}

- (void)dealloc
{
    [self setEmulator:nil];
    [self setThread:nil];
}

#pragma mark - ...

- (void)awakeFromNib
{
    [self setEmulator:[[AKEmulator alloc] init]];
    [[self thread] start];  // Actually create the thread
}

- (void)emulatorThreadMethod:(id)obj
{
    [[self emulator] runROM:@"sfiii"
                      error:NULL];
}

@end
