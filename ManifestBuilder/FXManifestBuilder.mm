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
- (NSDictionary *) romSets;
- (NSDictionary *) componentsForSets:(NSDictionary *) sets;
- (NSDictionary *) inputsForDriver:(int) driverId;

@end

@implementation FXManifestBuilder

- (void) writeManifests:(NSURL *) setPath
		  componentPath:(NSURL *) componentPath
{
	BurnLibInit();
	
	NSDictionary *sets = [self romSets];
	[sets writeToURL:setPath
		  atomically:NO];
	
	NSDictionary *components = [self componentsForSets:sets];
	[components writeToURL:componentPath
				atomically:NO];
	
	BurnLibExit();
}

- (NSString *) titleOfDriver:(int) index
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
											   encoding:NSASCIIStringEncoding];
		
		NSDictionary *set = @{
							  @"driver": @(index),
							  @"title": [self titleOfDriver:index],
							  @"width": @(pDriver[index]->nWidth),
							  @"height": @(pDriver[index]->nHeight),
							  @"system": [NSString stringWithCString:pDriver[index]->szSystemA
															encoding:NSASCIIStringEncoding],
							  @"input": [self inputsForDriver:index],
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

- (NSDictionary *) inputsForDriver:(int) driverId
{
	NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
	struct BurnInputInfo bii;
	for (int i = 0; i < 0x1000; i++) {
		if (pDriver[driverId]->GetInputInfo(&bii, i)) {
			break;
		}
		
		if (bii.nType == BIT_DIGITAL) {
			[inputs setObject:@{
								@"code": @(i + 1),
								@"desc": [NSString stringWithCString:bii.szName
															encoding:NSASCIIStringEncoding],
								}
					   forKey:[NSString stringWithCString:bii.szInfo
												 encoding:NSASCIIStringEncoding]];
		}
	}
	
	return inputs;
}

- (NSDictionary *) componentsForSets:(NSDictionary *) sets
{
	NSMutableDictionary *components = [NSMutableDictionary dictionary];
	[sets enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *info, BOOL * _Nonnull stop) {
		NSNumber *driver = [info objectForKey:@"driver"];
		[components setObject:[self componentsForDriver:[driver intValue]]
					   forKey:[driver stringValue]];
	}];
	
	return components;
}

- (NSArray *) componentsForDriver:(int) driverId
{
	NSMutableArray *array = [NSMutableArray array];
	
	NSArray *typeMasks = @[ @(BRF_ESS), @(BRF_BIOS), @(BRF_GRA), @(BRF_SND), @(BRF_PRG) ];
	NSArray *typeDescs = @[ @"essential", @"bios", @"graphics", @"sound", @"program" ];
	
	struct BurnRomInfo ri;
	for (int i = 0; ; i++) {
		if (pDriver[driverId]->GetRomInfo(&ri, i)) {
			break;
		}
		
		if (ri.nType == 0) {
			continue;
		}

		NSMutableString *types = [NSMutableString string];
		[typeDescs enumerateObjectsUsingBlock:^(NSString *typeDesc, NSUInteger idx, BOOL * _Nonnull stop) {
			if (ri.nType & (UINT32)[[typeMasks objectAtIndex:idx] unsignedIntegerValue]) {
				if ([types length] > 0) {
					[types appendString:@","];
				}
				[types appendString:typeDesc];
			}
		}];
		
		NSMutableArray *aliases = [NSMutableArray array];
		for (int aliasIndex = 0; aliasIndex < 0x10000; aliasIndex++) {
			char *cAlias = NULL;
			if (pDriver[driverId]->GetRomName(&cAlias, i, aliasIndex)) {
				break;
			}
			
			NSString *alias = [NSString stringWithCString:cAlias
												 encoding:NSUTF8StringEncoding];
			
			[aliases addObject:alias];
		}
		
		NSMutableDictionary *romInfo = [@{
										  @"name": [aliases firstObject],
										  @"len": @(ri.nLen),
										  @"crc": @(ri.nCrc),
										  @"type": types,
										  } mutableCopy];
		
		if ([aliases count] > 1) {
			[romInfo setObject:[aliases subarrayWithRange:NSMakeRange(1, [aliases count] - 1)]
						forKey:@"aliases"];
		}
		
		[array addObject:romInfo];
	}
	
	return array;
}

@end
