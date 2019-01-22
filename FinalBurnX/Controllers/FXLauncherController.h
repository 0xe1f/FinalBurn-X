/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) Akop Karapetyan
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
#import <Foundation/Foundation.h>

#import "FXDroppableScrollView.h"

@class FXDriver;

@interface FXLauncherController : NSWindowController<NSWindowDelegate, NSOutlineViewDataSource, FXScannerDelegate>
{
    IBOutlet NSPanel *importProgressPanel;
    IBOutlet NSProgressIndicator *importProgressBar;
    IBOutlet NSButton *importCancelButton;
    IBOutlet NSTextField *importProgressLabel;
    
    IBOutlet NSTreeController *driversTreeController;
    IBOutlet NSOutlineView *driversOutlineView;
    
    NSOperationQueue *importOpQueue;
    
    BOOL rescanROMsAtStartup;
}

- (IBAction)launchGame:(id)sender;
- (IBAction)cancelImport:(id)sender;
- (IBAction)rescanROMs:(id)sender;

@property (nonatomic, strong) NSMutableArray *drivers;

@end
