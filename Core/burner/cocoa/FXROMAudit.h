/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
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

@interface FXROMAudit : NSObject<NSCoding>

@property (nonatomic, copy) NSString *containerPath;

@property (nonatomic, copy) NSString *filenameNeeded;
@property (nonatomic, copy) NSString *filenameFound;
@property (nonatomic, assign) NSInteger lengthNeeded;
@property (nonatomic, assign) NSInteger lengthFound;
@property (nonatomic, assign) UInt32 CRCNeeded;
@property (nonatomic, assign) UInt32 CRCFound;
@property (nonatomic, assign) NSInteger type;

@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, copy) NSString *statusDescription;

- (BOOL)isExactMatch;

@end

enum {
    FXROMAuditOK         = 100,
    FXROMAuditBadCRC     = 101,
    FXROMAuditBadLength  = 102,
    FXROMAuditMissing    = 103,
};

enum {
    FXROMTypeNone        = 0x00,
    FXROMTypeGraphics    = 0x01,
    FXROMTypeSound       = 0x02,
    FXROMTypeEssential   = 0x04,
    FXROMTypeBIOS        = 0x08,
};
