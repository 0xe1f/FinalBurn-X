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
#import "FXROMInfo.h"

#include "burner.h"

@implementation FXROMInfo

- (instancetype)initWithBurnROMInfo:(const struct BurnRomInfo *)info
{
    if (self = [super init]) {
        self->knownAliases = [[NSMutableArray alloc] init];
        [self setLength:info->nLen];
        [self setCrc:info->nCrc];
        [self setType:info->nType];
    }
    
    return self;
}

- (void)addKnownAlias:(NSString *)alias
{
    [self->knownAliases addObject:alias];
}

- (NSArray *)knownAliases
{
    return [NSArray arrayWithArray:self->knownAliases];
}

@end
