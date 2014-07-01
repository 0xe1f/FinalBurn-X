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
        self->romAuditsByNeededCRC = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)addROMAudit:(FXROMAudit *)romAudit
{
    [self->romAuditsByNeededCRC setObject:romAudit
                                   forKey:@([romAudit CRCNeeded])];
}

- (FXROMAudit *)ROMAuditByNeededCRC:(NSUInteger)crc
{
    return [self->romAuditsByNeededCRC objectForKey:@(crc)];
}

- (NSArray *)ROMAudits
{
    return [self->romAuditsByNeededCRC allValues];
}

- (BOOL)isPerfect
{
    __block BOOL isPerfect = YES;
    [self->romAuditsByNeededCRC enumerateKeysAndObjectsUsingBlock:^(id key, FXROMAudit *romAudit, BOOL *stop) {
        if ([romAudit status] != FXROMAuditOK) {
            isPerfect = NO;
            *stop = YES;
        }
    }];
    
    return isPerfect;
}
@end
