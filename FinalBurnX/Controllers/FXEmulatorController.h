//
//  FXEmulatorController.h
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/17/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AKScreenView.h"

@class AKEmulator;
@class FXInput;

@interface FXEmulatorController : NSWindowController<NSWindowDelegate>
{
    IBOutlet AKScreenView *screen;
    
    @private
    AKEmulator *_emulator;
    FXInput *_input;
    NSThread *_thread;
}

@property (nonatomic, strong) AKEmulator *emulator;
@property (nonatomic, strong) FXInput *input;

@property (nonatomic, strong) NSThread *thread;

@end
