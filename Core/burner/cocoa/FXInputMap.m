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
#import "FXInputMap.h"

#import "AKKeyEventData.h"

@implementation FXInputMap

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self->physicalToVirtualCodeMap = [NSMutableDictionary dictionary];
        self->virtualToPhysicalCodeMap = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)assignKeyCode:(NSInteger)keyCode
               toCode:(NSString *)code
{
    NSNumber *kc = @(keyCode);
    [self->physicalToVirtualCodeMap setObject:code
                                       forKey:kc];
    [self->virtualToPhysicalCodeMap setObject:kc
                                       forKey:code];
    
    self->_dirty = YES;
}

- (NSInteger)keyCodeAssignedToCode:(NSString *)code
{
    NSNumber *kc = [virtualToPhysicalCodeMap objectForKey:code];
    if (kc == nil) {
        return AKKeyInvalid;
    }
    
    return [kc integerValue];
}

- (NSString *)codeAssignedToKeyCode:(NSInteger)keyCode
{
    return [physicalToVirtualCodeMap objectForKey:@(keyCode)];
}

- (void)markClean
{
    self->_dirty = NO;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        self->virtualToPhysicalCodeMap = [coder decodeObjectForKey:@"virtualToPhysicalCodeMap"];
        self->physicalToVirtualCodeMap = [coder decodeObjectForKey:@"physicalToVirtualCodeMap"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self->virtualToPhysicalCodeMap
                 forKey:@"virtualToPhysicalCodeMap"];
    [coder encodeObject:self->physicalToVirtualCodeMap
                 forKey:@"physicalToVirtualCodeMap"];
}

@end
