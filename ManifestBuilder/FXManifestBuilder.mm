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

- (NSString *) titleOfArchive:(int) index;
- (NSDictionary *) romSets;

@end

@implementation FXManifestBuilder

- (void) writeManifest:(NSURL *) path
{
	BurnLibInit();
	
	NSDictionary *sets = [self romSets];
	[sets writeToURL:path
		  atomically:NO];
	
	BurnLibExit();
}

- (NSString *) titleOfArchive:(int) index
{
#ifdef wcslen
#undef wcslen
#endif
	NSString *title = nil;
	const wchar_t *fullName = pDriver[index]->szFullNameW;

//	if (fullName != NULL) {
//		title = [[NSString alloc] initWithBytes:fullName
//										 length:sizeof(wchar_t) * wcslen(fullName)
//									   encoding:NSUTF8StringEncoding];
//	}
	
	if (title == nil) {
		title = [NSString stringWithCString:pDriver[index]->szFullNameA
								   encoding:NSUTF8StringEncoding];
	}
	
	return title;
}

- (NSDictionary *) romSets
{
	NSMutableDictionary *indexMap = [NSMutableDictionary dictionary];
	NSMutableDictionary *setMap = [NSMutableDictionary dictionary];
	
	for (int index = 0; index < nBurnDrvCount; index++) {
		UInt32 hardware = pDriver[index]->Hardware & HARDWARE_PUBLIC_MASK;
		if ((hardware != HARDWARE_CAPCOM_CPS1) &&
			(hardware != HARDWARE_CAPCOM_CPS1_GENERIC) &&
			(hardware != HARDWARE_CAPCOM_CPS1_QSOUND) &&
			(hardware != HARDWARE_CAPCOM_CPS2) &&
			(hardware != HARDWARE_CAPCOM_CPS2_SIMM) &&
			(hardware != HARDWARE_CAPCOM_CPS3) &&
			(hardware != HARDWARE_CAPCOM_CPS3_NO_CD) &&
			//            (hardware != HARDWARE_PREFIX_KONAMI) &&
			(hardware != (HARDWARE_SNK_NEOGEO | HARDWARE_PREFIX_CARTRIDGE))) {
			// Don't care
			continue;
		}
		
		NSString *archive = [NSString stringWithCString:pDriver[index]->szShortName
											   encoding:NSUTF8StringEncoding];
		
		NSDictionary *set = @{
							  @"driver": @(index),
							  @"title": [self titleOfArchive:index],
							  @"width": @(pDriver[index]->nWidth),
							  @"height": @(pDriver[index]->nHeight),
							  @"system": [NSString stringWithCString:pDriver[index]->szSystemA
															encoding:NSUTF8StringEncoding],
							  };

		[indexMap setObject:@(index)
					 forKey:archive];

		[setMap setObject:[set mutableCopy]
				   forKey:archive];
	}
	
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	[setMap enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *set, BOOL *stop) {
		int driverIndex = [[indexMap objectForKey:archive] intValue];
		
		if (pDriver[driverIndex]->szParent != NULL) {
			NSString *parentArchive = [NSString stringWithCString:pDriver[driverIndex]->szParent
														 encoding:NSUTF8StringEncoding];
			NSMutableDictionary *parentSet = [setMap objectForKey:parentArchive];
			
			NSMutableDictionary *subsets = [parentSet objectForKey:@"subsets"];
			if (subsets == nil) {
				subsets = [NSMutableDictionary dictionary];
				[parentSet setObject:subsets
							  forKey:@"subsets"];
			}
			
			[subsets setObject:set
						forKey:archive];
		} else {
			[dictionary setObject:set
						   forKey:archive];
		}
	}];
	
	return dictionary;
}

@end
