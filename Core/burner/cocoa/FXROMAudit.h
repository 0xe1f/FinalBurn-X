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

@interface FXROMAudit : NSObject<NSCoding>

@property (nonatomic, copy) NSString *containerPath;

@property (nonatomic, copy) NSString *filenameNeeded;
@property (nonatomic, copy) NSString *filenameFound;
@property (nonatomic, assign) NSInteger lengthNeeded;
@property (nonatomic, assign) NSInteger lengthFound;
@property (nonatomic, assign) UInt32 CRCNeeded;
@property (nonatomic, assign) UInt32 CRCFound;
@property (nonatomic, assign) NSInteger type;

- (NSInteger)status;
- (NSString *)message;

@end

enum {
    FXROMAuditOK         = 100,
    FXROMAuditBadCRC     = 101,
    FXROMAuditBadLength  = 102,
    FXROMAuditMissing    = 103,
};

enum {
    FXROMTypeNone        = 0x00,
    FXROMTypeGraphics    = 0x01,
    FXROMTypeSound       = 0x02,
    FXROMTypeEssential   = 0x04,
    FXROMTypeCoreSet = 0x08,
};
