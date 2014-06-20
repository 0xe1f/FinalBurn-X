//
//  AKAppDelegate.h
//  FinalBurn X
//
//  Created by Akop Karapetyan on 6/10/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FXEmulatorController.h"

@interface AKAppDelegate : NSObject <NSApplicationDelegate>
{
    FXEmulatorController *_emulator;
}

@property (nonatomic, strong) FXEmulatorController *emulator;

+ (AKAppDelegate *)sharedInstance;

@end
