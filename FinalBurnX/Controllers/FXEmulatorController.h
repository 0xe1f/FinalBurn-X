/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/pokebyte/FinalBurn-X
 ** Copyright (C) 2014-2016 Akop Karapetyan
 **
 ** Licensed under the Apache License, Version 2.0 (the "License");
 ** you may not use this file except in compliance with the License.
 ** You may obtain a copy of the License at
 **
 **     http://www.apache.org/licenses/LICENSE-2.0
 **
 ** Unless required by applicable law or agreed to in writing, software
 ** distributed under the License is distributed on an "AS IS" BASIS,
 ** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 ** See the License for the specific language governing permissions and
 ** limitations under the License.
 **
 ******************************************************************************
 */
#import <Cocoa/Cocoa.h>

#import "FXScreenView.h"
#import "FXVideo.h"
#import "FXInput.h"
#import "FXAudio.h"
#import "FXRunLoop.h"

#define FXEmulatorChanged @"org.akop.fbx.EmulatorChanged"
#define FXROMSetInfo @"romSet"

@class FXDriver;

@interface FXEmulatorController : NSWindowController<NSWindowDelegate, FXRunLoopDelegate, FXScreenViewDelegate>
{
    IBOutlet FXScreenView *screen;
    IBOutlet NSView *spinner;
	IBOutlet NSView *messagePane;
}

@property (nonatomic, readonly) FXInput *input;
@property (nonatomic, readonly) FXVideo *video;
@property (nonatomic, readonly) FXAudio *audio;
@property (nonatomic, readonly) FXRunLoop *runLoop;
@property (nonatomic, readonly) FXDriver *driver;

- (IBAction)saveScreenshot:(id)sender;
- (IBAction)saveScreenshotAs:(id)sender;

- (IBAction)resizeNormalSize:(id)sender;
- (IBAction)resizeDoubleSize:(id)sender;
- (IBAction)pauseGameplay:(id)sender;

- (IBAction)resetEmulation:(id)sender;
- (IBAction)toggleTestMode:(id)sender;

- (instancetype) initWithDriver:(FXDriver *) driver;

- (void)saveSettings;
- (void)restoreSettings;

+ (void)initializeCore;
+ (void)cleanupCore;

@end
