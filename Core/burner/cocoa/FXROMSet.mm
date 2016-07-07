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
#import "FXROMSet.h"

#include <wchar.h>
#include "burnint.h"
#include "driverlist.h"

@interface FXROMSet ()

+ (NSString *)archiveForDriverIndex:(int)driverId;
+ (NSString *)titleOfArchive:(NSString *)archive;
+ (NSSize)screenSizeOfArchive:(NSString *)archive;
+ (BOOL)romInfoOfArchive:(NSString *)archive
                romIndex:(int)romIndex
                 romInfo:(struct BurnRomInfo *)romInfo;

@end

@implementation FXROMSet

#pragma mark - Init & dealloc

- (instancetype)initWithArchive:(NSString *)archive
{
    if ((self = [super init]) != nil) {
        _subsets = [NSMutableArray array];
        
        [self setArchive:archive];
        [self setTitle:[FXROMSet titleOfArchive:archive]];
        [self setScreenSize:[FXROMSet screenSizeOfArchive:archive]];
    }
    
    return self;
}

#pragma mark - Static

+ (int)driverIndexOfArchive:(NSString *)archive
{
    const char *cArchive = [archive cStringUsingEncoding:NSASCIIStringEncoding];
    for (int i = 0; i < nBurnDrvCount; i++) {
        if (strcmp(pDriver[i]->szShortName, cArchive) == 0) {
            return i;
        }
    }
    
    return -1;
}

+ (NSString *)archiveForDriverIndex:(int)driverId
{
    if (driverId < 0 || driverId > nBurnDrvCount) {
        return nil;
    }
    
    return [NSString stringWithCString:pDriver[driverId]->szShortName
                              encoding:NSUTF8StringEncoding];
}

+ (NSString *)titleOfArchive:(NSString *)archive
{
    int driverIndex = [self driverIndexOfArchive:archive];
    if (driverIndex < 0) {
        return nil;
    }
    
#ifdef wcslen
#undef wcslen
#endif
	NSString *title = nil;
	const wchar_t *fullName = pDriver[driverIndex]->szFullNameW;
	if (fullName != NULL) {
		title = [[NSString alloc] initWithBytes:fullName
										 length:sizeof(wchar_t) * wcslen(fullName)
									   encoding:NSUTF32LittleEndianStringEncoding];
	}
	
	if (title == nil) {
		title = [NSString stringWithCString:pDriver[driverIndex]->szFullNameA
								   encoding:NSASCIIStringEncoding];
	}
    
    return title;
}

+ (NSSize)screenSizeOfArchive:(NSString *)archive
{
    int driverIndex = [self driverIndexOfArchive:archive];
    if (driverIndex < 0) {
        return NSZeroSize;
    }
    
	int width = pDriver[driverIndex]->nWidth;
	int height = pDriver[driverIndex]->nHeight;
    
	return NSMakeSize(width, height);
}

+ (BOOL)romInfoOfArchive:(NSString *)archive
                        romIndex:(int)romIndex
                         romInfo:(struct BurnRomInfo *)romInfo
{
    int driverIndex = [self driverIndexOfArchive:archive];
    if (driverIndex < 0) {
        return NO;
    }
    
    if (pDriver[driverIndex]->GetRomInfo(romInfo, romIndex)) {
        return NO;
    }
    
    return YES;
}

@end
