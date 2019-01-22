/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
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

#import "FXROMAudit.h"

@interface FXDriverAudit : NSObject<NSCoding>

@property (nonatomic, assign) NSInteger availability;
@property (nonatomic, assign) BOOL isPlayable;
@property (nonatomic, readonly) NSMutableArray *romAudits;

- (FXROMAudit *)findROMAuditByNeededCRC:(UInt32)crc;

@end

enum {
    FXDriverMissing     = 0,
    FXDriverUnplayable  = 1,
    FXDriverPartial     = 2,
    FXDriverComplete    = 3,
};
