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

#import "FXEmulatorController.h"
#import "FXLauncherController.h"
#import "FXPreferencesController.h"

@interface FXAppDelegate : NSObject <NSApplicationDelegate>

+ (FXAppDelegate *)sharedInstance;

- (NSURL *)appSupportURL;
- (FXPreferencesController *)prefs;
- (NSString *)ROMPath;
- (void) launch:(NSString *) name;

- (IBAction)showLauncher:(id)sender;
- (IBAction)showPreferences:(id)sender;

@property (nonatomic, readonly, strong) NSString *nvramPath;
@property (nonatomic, readonly, strong) NSString *inputMapPath;

@property (nonatomic, readonly) FXEmulatorController *emulator;

@end
