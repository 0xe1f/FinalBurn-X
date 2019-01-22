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
#import "FXROMAudit.h"

@implementation FXROMAudit

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        _containerPath = [coder decodeObjectForKey:@"containerPath"];
        _filenameNeeded = [coder decodeObjectForKey:@"filenameNeeded"];
        _filenameFound = [coder decodeObjectForKey:@"filenameFound"];
        _lengthNeeded = [coder decodeIntegerForKey:@"lengthNeeded"];
        _lengthFound = [coder decodeIntegerForKey:@"lengthFound"];
        _CRCNeeded = (UInt32)[coder decodeInt64ForKey:@"crcNeeded"];
        _CRCFound = (UInt32)[coder decodeInt64ForKey:@"crcFound"];
        _type = [coder decodeIntegerForKey:@"type"];
        _statusCode = [coder decodeIntegerForKey:@"statusCode"];
        _statusDescription = [coder decodeObjectForKey:@"statusDescription"];
    }
    
    return self;
}

- (BOOL)isExactMatch
{
    return [self CRCNeeded] == [self CRCFound];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self containerPath] forKey:@"containerPath"];
    [coder encodeObject:[self filenameNeeded] forKey:@"filenameNeeded"];
    [coder encodeObject:[self filenameFound] forKey:@"filenameFound"];
    [coder encodeInteger:[self lengthNeeded] forKey:@"lengthNeeded"];
    [coder encodeInteger:[self lengthFound] forKey:@"lengthFound"];
    [coder encodeInt64:[self CRCNeeded] forKey:@"crcNeeded"];
    [coder encodeInt64:[self CRCFound] forKey:@"crcFound"];
    [coder encodeInteger:[self type] forKey:@"type"];
    [coder encodeInteger:[self statusCode] forKey:@"statusCode"];
    [coder encodeObject:[self statusDescription] forKey:@"statusDescription"];
}

@end
