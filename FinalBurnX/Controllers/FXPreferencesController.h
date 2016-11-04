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

#import "AKKeyCaptureView.h"
#import "AKKeyboardManager.h"

@interface FXButtonConfig : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *title;

@end

@interface FXPreferencesController : NSWindowController<NSTableViewDataSource, NSWindowDelegate, AKKeyboardEventDelegate>
{
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *contentTabView;
    IBOutlet NSTableView *inputTableView;
    IBOutlet NSTableView *dipswitchTableView;
    IBOutlet NSButton *resetDipSwitchesButton;
	IBOutlet NSSlider *volumeSlider;
}

- (IBAction) tabChanged:(id) sender;
- (IBAction) resetDipSwitchesClicked:(id) sender;
- (IBAction) showNextTab:(id) sender;
- (IBAction) showPreviousTab:(id) sender;

@end
