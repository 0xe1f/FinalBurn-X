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
#import <Foundation/Foundation.h>

#import "AKKeyboardManager.h"
#import "AKGamepadManager.h"
#import "FXDIPSwitchGroup.h"

@class FXDriver;
@class FXInputConfig;

@interface FXInput : NSObject<AKKeyboardEventDelegate, AKGamepadEventDelegate>

- (NSArray *) dipSwitches;

- (instancetype) initWithDriver:(FXDriver *) driver;

- (void) setFocus:(BOOL) focus;

- (void) save;
- (void) restore;

- (void) setDipSwitchSetting:(FXDIPSwitchSetting *) setting;
- (void) resetDipSwitches;

@property (nonatomic, assign, getter = isResetPressed) BOOL resetPressed;
@property (nonatomic, assign, getter = isTestPressed) BOOL testPressed;

@property (nonatomic, strong) FXInputConfig *config;

@end

enum {
    FXInputReset       = 0xff,
    FXInputDiagnostic  = 0xfe,
};
