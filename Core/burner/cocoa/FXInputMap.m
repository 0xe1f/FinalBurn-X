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
#import "FXInputInfo.h"

@interface FXInputMapItem : NSObject<NSCoding>

@property (nonatomic, assign) int inputCode;
@property (nonatomic, assign) NSInteger keyCode;
@property (nonatomic, copy) NSString *driverCode;

@end

@implementation FXInputMapItem

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        [self setInputCode:[coder decodeIntForKey:@"inputCode"]];
        [self setKeyCode:[coder decodeIntegerForKey:@"keyCode"]];
        [self setDriverCode:[coder decodeObjectForKey:@"driverCode"]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:self->_inputCode forKey:@"inputCode"];
    [coder encodeInteger:self->_keyCode forKey:@"keyCode"];
    [coder encodeObject:self->_driverCode forKey:@"driverCode"];
}

@end

@implementation FXInputMap

- (instancetype)initWithInputInfoArray:(NSArray *)inputInfoArray
{
    if ((self = [super init]) != nil) {
        self->inputs = [NSMutableArray array];
        [inputInfoArray enumerateObjectsUsingBlock:^(FXInputInfo *ii, NSUInteger idx, BOOL *stop) {
            FXInputMapItem *item = [[FXInputMapItem alloc] init];
            [item setInputCode:[ii inputCode]];
            [item setDriverCode:[ii code]];
            [item setKeyCode:AKKeyInvalid];
            
            [self->inputs addObject:item];
        }];
    }
    
    return self;
}

- (NSInteger)keyCodeForDriverCode:(NSString *)driverCode
{
    // FIXME: map
    __block NSInteger keyCode = AKKeyInvalid;
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([[item driverCode] isEqualToString:driverCode]) {
            keyCode = [item keyCode];
            *stop = YES;
        }
    }];
    
    return keyCode;
}

- (int)inputCodeForKeyCode:(NSInteger)keyCode
{
    // FIXME: map
    __block int inputCode = 0;
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([item keyCode] == keyCode) {
            inputCode = [item inputCode];
            *stop = YES;
        }
    }];
    
    return inputCode;
}

- (NSInteger)keyCodeForInputCode:(int)inputCode
{
    // FIXME: map
    __block NSInteger keyCode = AKKeyInvalid;
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([item inputCode] == inputCode) {
            keyCode = [item keyCode];
            *stop = YES;
        }
    }];
    
    return keyCode;
}

- (void)assignKeyCode:(NSInteger)keyCode
         toDriverCode:(NSString *)driverCode
{
    // FIXME: map
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([[item driverCode] isEqualToString:driverCode]) {
            [item setKeyCode:keyCode];
            *stop = YES;
        }
    }];
    
    self->_dirty = YES;
}

- (void)markClean
{
    self->_dirty = NO;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) != nil) {
        self->inputs = [coder decodeObjectForKey:@"inputs"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self->inputs forKey:@"inputs"];
}

@end
