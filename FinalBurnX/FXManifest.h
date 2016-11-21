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

@class FXDriverAudit; // FIXME!

@interface FXButton : NSObject

@property (nonatomic, assign) int code;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *title;

- (BOOL) isPlayerSpecific;
- (BOOL) isFireButton;
- (int) playerIndex;
- (int) fireIndex;
- (NSString *) neutralName;

- (NSString *) neutralTitle;

@end

@interface FXDriver : NSObject

@property (nonatomic, readonly) int index;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *system;
@property (nonatomic, readonly) NSSize screenSize;
@property (nonatomic, readonly) FXDriver *parent;
@property (nonatomic, readonly) NSArray<FXDriver *> *children;
@property (nonatomic, readonly) NSArray<FXButton *> *buttons;

// FIXME
@property (nonatomic, strong) FXDriverAudit *audit;

- (BOOL) usesStreetFighterLayout;
- (int) fireButtonCount;

@end

@interface FXManifest : NSObject

+ (FXManifest *) sharedInstance;
- (FXDriver *) driverNamed:(NSString *) name;

@property (nonatomic, readonly) NSArray<FXDriver *> *drivers;

@end
