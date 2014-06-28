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
#import "FXROMStatus.h"

@implementation FXROMStatus

- (NSInteger)status
{
    if ([self filenameFound] == nil) {
        return FXROMStatusMissing;
    } else {
        if ([self CRCNeeded] == [self CRCFound]) {
            return FXROMStatusOK;
        } else if ([self lengthFound] != [self lengthNeeded]) {
            return FXROMStatusBadLength;
        } else {
            return FXROMStatusBadCRC;
        }
    }
}

- (NSString *)message
{
    NSString *message = nil;
    switch ([self status]) {
        case FXROMStatusMissing:
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ not found", @""),
                       [self filenameNeeded]];
            break;
        case FXROMStatusBadCRC:
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ has an invalid checksum (wanted: %d; found: %d)", @""),
                       [self filenameFound], [self CRCNeeded], [self CRCFound]];
            break;
        case FXROMStatusBadLength:
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ has an invalid length (wanted: %d; found: %d)", @""),
                       [self filenameFound], [self lengthNeeded], [self lengthFound]];
            break;
        case FXROMStatusOK:
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ is OK", @""),
                       [self filenameFound]];
            break;
    }
    
    return message;
}

@end
