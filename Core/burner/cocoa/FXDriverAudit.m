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
