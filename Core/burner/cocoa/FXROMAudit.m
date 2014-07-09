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
            message = [NSString stringWithFormat:NSLocalizedString(@"Checksum mismatch (expected: %dB; found: %dB)", @""),
                       [self CRCNeeded], [self CRCFound]];
            break;
        case FXROMAuditBadLength:
            message = [NSString stringWithFormat:NSLocalizedString(@"Length mismatch (expected: %dB; found: %dB)", @""),
                       [self lengthNeeded], [self lengthFound]];
            break;
        case FXROMAuditOK:
            message = NSLocalizedString(@"OK", @"");
            break;
    }
    
    return message;
}

@end
