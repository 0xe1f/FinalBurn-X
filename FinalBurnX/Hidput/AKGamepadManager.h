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
#import <IOKit/hid/IOHIDLib.h>

#import "AKGamepad.h"
#import "AKGamepadEventData.h"

@protocol AKGamepadEventDelegate

@optional
- (void)gamepadDidConnect:(AKGamepad *)gamepad;
- (void)gamepadDidDisconnect:(AKGamepad *)gamepad;

- (void)gamepad:(AKGamepad *)gamepad
       xChanged:(NSInteger)newValue
         center:(NSInteger)center
      eventData:(AKGamepadEventData *)eventData;
- (void)gamepad:(AKGamepad *)gamepad
       yChanged:(NSInteger)newValue
         center:(NSInteger)center
      eventData:(AKGamepadEventData *)eventData;

- (void)gamepad:(AKGamepad *)gamepad
     buttonDown:(NSInteger)index
      eventData:(AKGamepadEventData *)eventData;
- (void)gamepad:(AKGamepad *)gamepad
       buttonUp:(NSInteger)index
      eventData:(AKGamepadEventData *)eventData;

@end

@interface AKGamepadManager : NSObject<AKGamepadEventDelegate>

+ (instancetype) sharedInstance;

- (AKGamepad *) gamepadWithId:(NSInteger) gamepadId;
- (AKGamepad *) gamepadAtIndex:(NSUInteger) index;

- (NSUInteger) gamepadCount;

- (void)addObserver:(id<AKGamepadEventDelegate>)observer;
- (void)removeObserver:(id<AKGamepadEventDelegate>)observer;

@end
