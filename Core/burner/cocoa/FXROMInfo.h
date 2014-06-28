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
#import <Foundation/Foundation.h>

struct BurnRomInfo;

@interface FXROMInfo : NSObject
{
    @private
    NSMutableArray *knownAliases;
}

- (instancetype)initWithBurnROMInfo:(const struct BurnRomInfo *)info;

- (void)addKnownAlias:(NSString *)alias;
- (NSArray *)knownAliases;

@property (nonatomic, assign) NSUInteger length;
@property (nonatomic, assign) NSUInteger crc;
@property (nonatomic, assign) NSUInteger type;

@end

enum {
    FXROMTypeCPU      = 0x90,
    FXROMTypeGraphics = 0x01,
    FXROMTypeSound    = 0x02,
};
