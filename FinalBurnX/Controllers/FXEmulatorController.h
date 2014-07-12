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
#import <Cocoa/Cocoa.h>

#import "FXScreenView.h"
#import "FXVideo.h"
#import "FXInput.h"
#import "FXAudio.h"
#import "FXRunLoop.h"

@interface FXEmulatorController : NSWindowController<NSWindowDelegate, FXVideoDelegate>
{
    IBOutlet FXScreenView *screen;
}

@property (nonatomic, strong) FXInput *input;
@property (nonatomic, strong) FXVideo *video;
@property (nonatomic, strong) FXAudio *audio;
@property (nonatomic, strong) FXRunLoop *runLoop;

@property (nonatomic, assign) int driverId;

- (IBAction)resizeNormalSize:(id)sender;
- (IBAction)resizeDoubleSize:(id)sender;

- (instancetype)initWithDriverId:(int)driverId;

+ (void)initializeCore;
+ (void)cleanupCore;

@end
