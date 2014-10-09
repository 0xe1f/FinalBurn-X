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

#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

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

@interface FXInputMap ()

- (void)restoreGenericDefaults;
- (void)restoreStreetFighterDefaults;

@end

@implementation FXInputMap

- (instancetype)initWithROMSet:(FXROMSet *)romSet
{
    if ((self = [super init]) != nil) {
        self->hardware = [romSet hardware];
        self->archive = [[romSet archive] copy];
        self->inputs = [NSMutableArray array];
        
        NSError *error = nil;
        NSArray *inputInfoArray = [FXInputMap inputsForDriver:[romSet archive]
                                                        error:&error];
        
        if (error == nil) {
            [inputInfoArray enumerateObjectsUsingBlock:^(FXInputInfo *ii, NSUInteger idx, BOOL *stop) {
                FXInputMapItem *item = [[FXInputMapItem alloc] init];
                [item setInputCode:[ii inputCode]];
                [item setDriverCode:[ii code]];
                [item setKeyCode:AKKeyInvalid];
                
                [self->inputs addObject:item];
            }];
        }
    }
    
    return self;
}

- (NSInteger)fireButtonCount
{
    __block NSInteger count = 0;
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([[item driverCode] hasPrefix:@"p1 fire "]) {
            count++;
        }
    }];
    
    return count;
}

- (BOOL)usesStreetFighterLayout
{
    if ((self->hardware != HARDWARE_CAPCOM_CPS1) &&
        (self->hardware != HARDWARE_CAPCOM_CPS1_GENERIC) &&
        (self->hardware != HARDWARE_CAPCOM_CPS1_QSOUND) &&
        (self->hardware != HARDWARE_CAPCOM_CPS2) &&
        (self->hardware != HARDWARE_CAPCOM_CPS2_SIMM) &&
        (self->hardware != HARDWARE_CAPCOM_CPS3) &&
        (self->hardware != HARDWARE_CAPCOM_CPS3_NO_CD)) {
        return NO;
    }
    
    return [self fireButtonCount] >= 6;
}

- (void)restoreGenericDefaults
{
    NSLog(@"Restoring Generic defaults");
    
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([[item driverCode] isEqualToString:@"p1 coin"]) {
            [item setKeyCode:AKKeyCode5];
        } else if ([[item driverCode] isEqualToString:@"p1 start"]) {
            [item setKeyCode:AKKeyCode1];
        } else if ([[item driverCode] isEqualToString:@"p1 up"]) {
            [item setKeyCode:AKKeyCodeUpArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 down"]) {
            [item setKeyCode:AKKeyCodeDownArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 left"]) {
            [item setKeyCode:AKKeyCodeLeftArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 right"]) {
            [item setKeyCode:AKKeyCodeRightArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 1"]) {
            [item setKeyCode:AKKeyCodeA];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 2"]) {
            [item setKeyCode:AKKeyCodeS];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 3"]) {
            [item setKeyCode:AKKeyCodeD];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 4"]) {
            [item setKeyCode:AKKeyCodeF];
        } else {
            NSLog(@"unrecognized code: %@", [item driverCode]);
        }
    }];
}

- (void)restoreStreetFighterDefaults
{
    NSLog(@"Restoring SF defaults");
    
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        if ([[item driverCode] isEqualToString:@"p1 coin"]) {
            [item setKeyCode:AKKeyCode5];
        } else if ([[item driverCode] isEqualToString:@"p1 start"]) {
            [item setKeyCode:AKKeyCode1];
        } else if ([[item driverCode] isEqualToString:@"p1 up"]) {
            [item setKeyCode:AKKeyCodeUpArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 down"]) {
            [item setKeyCode:AKKeyCodeDownArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 left"]) {
            [item setKeyCode:AKKeyCodeLeftArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 right"]) {
            [item setKeyCode:AKKeyCodeRightArrow];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 1"]) {
            [item setKeyCode:AKKeyCodeA];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 2"]) {
            [item setKeyCode:AKKeyCodeS];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 3"]) {
            [item setKeyCode:AKKeyCodeD];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 4"]) {
            [item setKeyCode:AKKeyCodeZ];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 5"]) {
            [item setKeyCode:AKKeyCodeX];
        } else if ([[item driverCode] isEqualToString:@"p1 fire 6"]) {
            [item setKeyCode:AKKeyCodeC];
        } else {
            NSLog(@"Unrecognized driver code: %@", [item driverCode]);
        }
    }];
}

- (void)restoreDefaults
{
    if ([self usesStreetFighterLayout]) {
        [self restoreStreetFighterDefaults];
    } else {
        [self restoreGenericDefaults];
    }
    
    self->_dirty = YES;
}

- (NSArray *)inputCodes
{
    NSMutableArray *inputCodes = [NSMutableArray array];
    [self->inputs enumerateObjectsUsingBlock:^(FXInputMapItem *item, NSUInteger idx, BOOL *stop) {
        [inputCodes addObject:@([item inputCode])];
    }];
    
    return inputCodes;
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
        self->archive = [coder decodeObjectForKey:@"archive"];
        self->hardware = (NSUInteger)[coder decodeIntegerForKey:@"hardware"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self->inputs forKey:@"inputs"];
    [coder encodeObject:self->archive forKey:@"archive"];
    [coder encodeInteger:self->hardware forKey:@"hardware"];
}

+ (NSArray *)inputsForDriver:(NSString *)archive
                       error:(NSError **)error
{
    int driverId = [FXROMSet driverIndexOfArchive:archive];
    if (driverId == -1) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"org.akop.fbx.Emulation"
                                         code:0
                                     userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"ROM set not recognized", @"") }];
        }
        
        return nil;
    }
    
    NSMutableArray *inputs = [NSMutableArray array];
    
    struct BurnInputInfo bii;
    for (int i = 0; i < 0x1000; i++) {
        if (pDriver[driverId]->GetInputInfo(&bii, i)) {
            break;
        }
        
        if (bii.nType == BIT_DIGITAL) {
            FXInputInfo *inputInfo = [[FXInputInfo alloc] initWithBurnInputInfo:&bii];
            
            int inputCode;
            if ([[inputInfo code] isEqualToString:@"reset"]) {
                inputCode = FXInputReset;
            } else if ([[inputInfo code] isEqualToString:@"diag"]) {
                inputCode = FXInputDiagnostic;
            } else {
                inputCode = i + 1;
            }
            
            [inputInfo setInputCode:inputCode];
            [inputs addObject:inputInfo];
        }
    }
    
    return inputs;
}

@end
