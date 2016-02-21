/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014-2016 Akop Karapetyan
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
#import "FXDIPSwitchGroup.h"

@implementation FXDIPSwitchGroup

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self->_settings = [NSMutableArray array];
    }
    
    return self;
}

- (void)enableSetting:(FXDIPSwitchSetting *)settingToEnable
{
    [self->_settings enumerateObjectsUsingBlock:^(FXDIPSwitchSetting *setting, NSUInteger idx, BOOL *stop) {
        if (settingToEnable == setting) {
            [setting setEnabled:YES];
        } else if ([setting isEnabled]) {
            [setting setEnabled:NO];
        }
    }];
}

- (BOOL)anyEnabled
{
    __block BOOL anyEnabled = NO;
    [self->_settings enumerateObjectsUsingBlock:^(FXDIPSwitchSetting *setting, NSUInteger idx, BOOL *stop) {
        if ([setting isEnabled]) {
            anyEnabled = YES;
            *stop = YES;
        }
    }];
    
    return anyEnabled;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        [self setName:[coder decodeObjectForKey:@"name"]];
        [self setFlags:(UInt8)[coder decodeIntForKey:@"flags"]];
        [self setIndex:[coder decodeIntForKey:@"index"]];
        self->_settings = [coder decodeObjectForKey:@"settings"];
        
        [self->_settings enumerateObjectsUsingBlock:^(FXDIPSwitchSetting *setting, NSUInteger idx, BOOL *stop) {
            // Set self as the group
            [setting setGroup:self];
        }];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self->_name forKey:@"name"];
    [coder encodeInt:self->_flags forKey:@"flags"];
    [coder encodeInt:self->_index forKey:@"index"];
    [coder encodeObject:self->_settings forKey:@"settings"];
}

@end
