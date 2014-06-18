//
//  AKEmulatorController.h
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/17/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AKScreenView.h"

@class AKEmulator;

@interface AKEmulatorController : NSWindowController
{
    IBOutlet AKScreenView *screen;
    
    @private
    AKEmulator *_emulator;
    NSThread *_thread;
}

@property (nonatomic, strong) AKEmulator *emulator;
@property (nonatomic, strong) NSThread *thread;

@end
