/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
    }
    
    return self;
}

- (NSInteger)status
{
    if ([self filenameFound] == nil) {
        return FXROMAuditMissing;
    } else {
        if ([self CRCNeeded] == [self CRCFound]) {
            return FXROMAuditOK;
        } else if ([self lengthFound] != [self lengthNeeded]) {
            return FXROMAuditBadLength;
        } else {
            return FXROMAuditBadCRC;
        }
    }
}

- (NSString *)message
{
    NSString *message = nil;
    switch ([self status]) {
        case FXROMAuditMissing:
            message = NSLocalizedString(@"Missing", @"");
            break;
        case FXROMAuditBadCRC:
            message = [NSString stringWithFormat:NSLocalizedString(@"Checksum mismatch (expected: %08x; found: %08x)", @""),
                       [self CRCNeeded], [self CRCFound]];
            break;
        case FXROMAuditBadLength:
            message = [NSString stringWithFormat:NSLocalizedString(@"Length mismatch (expected: %dkB; found: %dkB)", @""),
                       [self lengthNeeded] >> 10, [self lengthFound] >> 10];
            break;
        case FXROMAuditOK:
            message = NSLocalizedString(@"OK", @"");
            break;
    }
    
    return message;
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
}

@end
