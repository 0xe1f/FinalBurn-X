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
#import "FXROMSet.h"

#include <wchar.h>
#include "burnint.h"
#include "driverlist.h"

@implementation FXROMSet

#pragma mark - Init & dealloc

- (instancetype)initWithDriverId:(int)driverId
{
    if (self = [super init]) {
        [self setDriverId:driverId];
        [self setTitle:[FXROMSet titleOfSetWithDriverId:driverId]];
        [self setScreenSize:[FXROMSet screenSizeOfSetWithDriverId:driverId]];
    }
    
    return self;
}

+ (NSString *)titleOfSetWithDriverId:(int)driverId
{
#ifdef wcslen
#undef wcslen
#endif
    NSString *title = nil;
    const wchar_t *fullName = pDriver[driverId]->szFullNameW;
    
    if (fullName != NULL) {
        title = [[NSString alloc] initWithBytes:fullName
                                         length:sizeof(wchar_t) * wcslen(fullName)
                                       encoding:NSUTF8StringEncoding];
    }
    
    if (title == nil) {
        title = [NSString stringWithCString:pDriver[driverId]->szFullNameA
                                   encoding:NSUTF8StringEncoding];
    }
    
    return title;
}

+ (NSSize)screenSizeOfSetWithDriverId:(int)driverId
{
	int width = pDriver[driverId]->nWidth;
	int height = pDriver[driverId]->nHeight;
    
	return NSMakeSize(width, height);
}

@end
