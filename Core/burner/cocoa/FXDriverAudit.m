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
#import "FXDriverAudit.h"

@implementation FXDriverAudit

- (instancetype)init
{
    if (self = [super init]) {
        self->_romAudits = [NSMutableArray array];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        self->_availability = [coder decodeIntegerForKey:@"availability"];
        self->_isPlayable = [coder decodeBoolForKey:@"isPlayable"];
        self->_romAudits = [coder decodeObjectForKey:@"romAudits"];
    }
    
    return self;
}


- (FXROMAudit *)findROMAuditByNeededCRC:(UInt32)crc
{
    __block FXROMAudit *found = nil;
    [self->_romAudits enumerateObjectsUsingBlock:^(FXROMAudit *romAudit, NSUInteger idx, BOOL *stop) {
        if ([romAudit CRCNeeded] == crc) {
            found = romAudit;
            *stop = YES;
        }
    }];
    
    return found;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:[self availability] forKey:@"availability"];
    [coder encodeBool:[self isPlayable] forKey:@"isPlayable"];
    [coder encodeObject:[self romAudits] forKey:@"romAudits"];
}

@end
