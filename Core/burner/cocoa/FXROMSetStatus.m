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
#import "FXROMSetStatus.h"

#import "FXROMInfo.h"

@implementation FXROMSetStatus

- (instancetype)init
{
    if (self = [super init]) {
        self->romStatuses = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (instancetype)initWithArchiveNamed:(NSString *)archiveName
{
    if (self = [self init]) {
        [self setArchiveName:archiveName];
    }
    
    return self;
}

- (void)addROMStatus:(FXROMStatus *)romStatus
{
    [self->romStatuses addObject:romStatus];
}

- (BOOL)isArchiveFound
{
    return [self path] != nil;
}

- (NSArray *)ROMStatuses;
{
    return [NSArray arrayWithArray:self->romStatuses];
}

- (BOOL)isComplete
{
    if ([self->romStatuses count] < 1) {
        return NO;
    }
    
    __block BOOL complete = YES;
    [self->romStatuses enumerateObjectsUsingBlock:^(FXROMStatus *status, NSUInteger idx, BOOL *stop) {
        if ([status status] != FXROMStatusOK) {
            complete = NO;
            *stop = YES;
        }
    }];
    
    return complete;
}

@end
