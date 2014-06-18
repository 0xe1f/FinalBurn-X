//
//  AKAppDelegate.h
//  FinalBurn X
//
//  Created by Akop Karapetyan on 6/10/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AKEmulatorController.h"

@interface AKAppDelegate : NSObject <NSApplicationDelegate>
{
    AKEmulatorController *_emulator;
}

@property (nonatomic, strong) AKEmulatorController *emulator;

+ (AKAppDelegate *)instance;

@end
