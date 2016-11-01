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
#import "FXManifestBuilder.h"

#include <wchar.h>

#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

@interface FXManifestBuilder()

- (NSString *) titleOfDriver:(int) index;
- (NSDictionary *) inputsForDriver:(int) driverId;
- (NSMutableDictionary *) componentsForDriver:(int) driverIndex;
- (void) pruneCommonSubsetFilesIn:(NSMutableDictionary *) outer;
- (BOOL) isSupportingDriver:(NSInteger) index;

@end

@implementation FXManifestBuilder

- (instancetype)init
{
	if ((self = [super init])) {
		BurnLibInit();
	}
	return self;
}

- (void) dealloc
{
	BurnLibExit();
}

- (NSString *) titleOfDriver:(int) index
{
#ifdef wcslen
#undef wcslen
#endif
	NSString *title = nil;
	const wchar_t *fullName = pDriver[index]->szFullNameW;
	if (fullName != NULL) {
		title = [[NSString alloc] initWithBytes:fullName
										 length:sizeof(wchar_t) * wcslen(fullName)
									   encoding:NSUTF32LittleEndianStringEncoding];
	}
	
	if (title == nil) {
		title = [NSString stringWithCString:pDriver[index]->szFullNameA
								   encoding:NSASCIIStringEncoding];
	}
	
	return title;
}

- (BOOL) isSupportingDriver:(NSInteger) index
{
	BOOL supported = NO;
	UInt32 hardware = pDriver[index]->Hardware & HARDWARE_PUBLIC_MASK;
	switch (hardware) {
		case HARDWARE_CAPCOM_CPS1:
		case HARDWARE_CAPCOM_CPS1_GENERIC:
		case HARDWARE_CAPCOM_CPS1_QSOUND:
		case HARDWARE_CAPCOM_CPS2:
		case HARDWARE_CAPCOM_CPS2_SIMM:
		case HARDWARE_CAPCOM_CPS3:
		case HARDWARE_CAPCOM_CPS3_NO_CD:
			// Capcom
			supported = YES;
			break;
		case HARDWARE_SNK_NEOGEO | HARDWARE_PREFIX_CARTRIDGE:
			// Basic Neo-Geo
			supported = YES;
			break;
		case HARDWARE_SNK_NEOGEO:
			// Supported if it's the Neo-Geo BIOS
			supported = (pDriver[index]->Flags & BDF_BOARDROM) != 0;
			break;
		default:
			// Unsupported
			break;
	}
	
	return supported;
}

- (NSDictionary *) romSets
{
	NSMutableDictionary *setMap = [NSMutableDictionary dictionary];
	NSMutableArray *attrs = [NSMutableArray array];
	
	for (int index = 0; index < nBurnDrvCount; index++) {
		if (![self isSupportingDriver:index]) {
			continue;
		}
		
		NSString *archive = [NSString stringWithCString:pDriver[index]->szShortName
											   encoding:NSASCIIStringEncoding];
		
		NSMutableDictionary *set = [@{ @"driver": @(index),
									   @"title": [self titleOfDriver:index],
									   @"width": @(pDriver[index]->nWidth),
									   @"height": @(pDriver[index]->nHeight),
									   @"system": [NSString stringWithCString:pDriver[index]->szSystemA
																	 encoding:NSASCIIStringEncoding],
									   @"input": [self inputsForDriver:index],
									   } mutableCopy];
		
		if (pDriver[index]->szBoardROM) {
			[set setObject:[NSString stringWithCString:pDriver[index]->szBoardROM
											  encoding:NSASCIIStringEncoding]
					forKey:@"bios"];
		}
		if (pDriver[index]->szParent) {
			[set setObject:[NSString stringWithCString:pDriver[index]->szParent
											 encoding:NSASCIIStringEncoding]
					forKey:@"parent"];
		}
		
		[attrs removeAllObjects];
		if (pDriver[index]->Flags & BDF_ORIENTATION_VERTICAL) {
			[attrs addObject:@"rotated"];
		}
		if (pDriver[index]->Flags & BDF_ORIENTATION_FLIPPED) {
			[attrs addObject:@"flipped"];
		}
		if ((pDriver[index]->Flags & BDF_GAME_WORKING) != BDF_GAME_WORKING) {
			[attrs addObject:@"unplayable"];
		}
		if ([attrs count] > 0) {
			[set setObject:[attrs componentsJoinedByString:@","]
					forKey:@"attrs"];
		}
		
		NSMutableDictionary *components = [self componentsForDriver:index];
		[set addEntriesFromDictionary:components];
		
		[setMap setObject:set
				   forKey:archive];
	}
	
	[self pruneCommonSubsetFilesIn:setMap];
	
	return setMap;
}

- (NSDictionary *) inputsForDriver:(int) driverId
{
	NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
	struct BurnInputInfo bii;
	for (int i = 0; i < 0x1000; i++) {
		if (pDriver[driverId]->GetInputInfo(&bii, i)) {
			break;
		}
		
		if (bii.nType == BIT_DIGITAL) {
			[inputs setObject:@{ @"code": @(i + 1),
								 @"title": [NSString stringWithCString:bii.szName
															encoding:NSASCIIStringEncoding] }
					   forKey:[NSString stringWithCString:bii.szInfo
												 encoding:NSASCIIStringEncoding]];
		}
	}
	
	return inputs;
}

- (NSMutableDictionary *) componentsForDriver:(int) driverIndex
{
	NSMutableDictionary *outer = [NSMutableDictionary dictionary];
	NSMutableDictionary *files = [NSMutableDictionary dictionary];
	
	[outer setObject:[@{ @"local": files } mutableCopy]
			  forKey:@"files"];
	
	struct BurnRomInfo ri;
	for (int i = 0; ; i++) {
		if (pDriver[driverIndex]->GetRomInfo(&ri, i)) {
			break;
		}
		
		if (ri.nType == 0) {
			continue;
		}
		
		char *cAlias = NULL;
		if (pDriver[driverIndex]->GetRomName(&cAlias, i, 0)) {
			continue;
		}
		
		NSMutableDictionary *romInfo = [@{ @"len": @(ri.nLen),
										   @"crc": @(ri.nCrc) } mutableCopy];
		
		if (ri.nType & BRF_OPT) {
			[romInfo setObject:@"optional"
						forKey:@"attrs"];
		}
		
		[files setObject:romInfo
				  forKey:[NSString stringWithCString:cAlias
						   encoding:NSASCIIStringEncoding]];
	}
	
	return outer;
}

- (void) pruneCommonSubsetFilesIn:(NSMutableDictionary *) sets
{
	[sets enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSMutableDictionary *set, BOOL * _Nonnull stop) {
		NSMutableDictionary *subFiles = [[set objectForKey:@"files"] objectForKey:@"local"];
		
		NSString *bios = [set objectForKey:@"bios"];
		if (bios) {
			NSDictionary *biosFiles = [[[sets objectForKey:bios] objectForKey:@"files"] objectForKey:@"local"];
			
			NSMutableArray *commonInParent = [NSMutableArray array];
			[[subFiles copy] enumerateKeysAndObjectsUsingBlock:^(NSString *fileName, NSDictionary *fileInfo, BOOL * _Nonnull stop) {
				if ([biosFiles objectForKey:fileName]) {
					[subFiles removeObjectForKey:fileName];
					[commonInParent addObject:fileName];
				}
			}];
			
			if ([commonInParent count] > 0) {
				[[set objectForKey:@"files"] setObject:commonInParent
												forKey:@"bios"];
			}
		}
		
		NSString *parent = [set objectForKey:@"parent"];
		if (parent) {
			NSDictionary *parentFiles = [[[sets objectForKey:parent] objectForKey:@"files"] objectForKey:@"local"];
			NSMutableArray *commonInParent = [NSMutableArray array];
			[[subFiles copy] enumerateKeysAndObjectsUsingBlock:^(NSString *fileName, NSDictionary *fileInfo, BOOL * _Nonnull stop) {
				if ([parentFiles objectForKey:fileName]) {
					[subFiles removeObjectForKey:fileName];
					[commonInParent addObject:fileName];
				}
			}];
			
			if ([commonInParent count] > 0) {
				[[set objectForKey:@"files"] setObject:commonInParent
												forKey:@"parent"];
			}
		}
	}];
}

@end
