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
#import "FXButtonMap.h"

#import "AKKeyEventData.h"
#import "FXManifest.h"

@interface FXButtonMap ()

- (BOOL) usesStreetFighterLayout:(FXDriver *) driver;
- (void) restoreGenericDefaults:(FXDriver *) driver;
- (void) restoreStreetFighterDefaults:(FXDriver *) driver;
- (void) resetAll;

@end

#define MAP_SIZE 256

@implementation FXButtonMap
{
	unsigned int _deviceToVirtualMap[MAP_SIZE];
	unsigned int _virtualToDeviceMap[MAP_SIZE];
}

#pragma mark - init, dealloc

- (instancetype) init
{
	if (self = [super init]) {
		[self resetAll];
	}

	return self;
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if ((self = [super init]) != nil) {
		[self resetAll];

		NSDictionary<NSNumber *, NSNumber *> *map = [coder decodeObjectForKey:@"map"];
		[map enumerateKeysAndObjectsUsingBlock:^(NSNumber *d, NSNumber *v, BOOL *stop) {
			int di = [d intValue];
			int vi = [v intValue];
			_deviceToVirtualMap[di] = vi;
			_virtualToDeviceMap[vi] = di;
		}];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	NSMutableDictionary<NSNumber *, NSNumber *> *map = [NSMutableDictionary dictionary];
	for (int i = 0; i < MAP_SIZE; i++) {
		int code = _deviceToVirtualMap[i];
		if (code != FXMappingNotFound) {
			[map setObject:@(i) forKey:@(code)];
		}
	}
	[coder encodeObject:map forKey:@"map"];
}

#pragma mark - Public

- (int) keyCodeMatching:(int) code
{
	if (code < 0 || code >= MAP_SIZE) {
		return 0;
	}

	return _virtualToDeviceMap[code];
}

- (void) markClean
{
	_dirty = NO;
}

- (void) restoreDefaults:(FXDriver *) driver
{
	[self resetAll];

	if ([self usesStreetFighterLayout:driver]) {
		[self restoreStreetFighterDefaults:driver];
	} else {
		[self restoreGenericDefaults:driver];
	}

	_dirty = YES;
}

#pragma mark - Private

- (void) resetAll
{
	memset(&_deviceToVirtualMap, 0xff, sizeof(_deviceToVirtualMap));
	memset(&_virtualToDeviceMap, 0xff, sizeof(_virtualToDeviceMap));
}

- (BOOL) usesStreetFighterLayout:(FXDriver *) driver
{
	if (![[driver system] hasPrefix:@"CPS"]) {
		return NO;
	}
	
	__block NSInteger count = 0;
	[[driver buttons] enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		if ([[b name] hasPrefix:@"p1 fire "]) {
			if (++count >= 6) {
				*stop = YES;
			}
		}
	}];
	return count >= 6;
}

- (void) restoreGenericDefaults:(FXDriver *) driver
{
	[[driver buttons] enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		if (idx > 255) {
			*stop = YES;
			return;
		}

		int code = [b code]; // (int) idx + 1;
		if ([[b name] isEqualToString:@"p1 coin"]) {
			_deviceToVirtualMap[AKKeyCode5] = code;
			_virtualToDeviceMap[code] = AKKeyCode5;
		} else if ([[b name] isEqualToString:@"p1 start"]) {
			_deviceToVirtualMap[AKKeyCode1] = code;
			_virtualToDeviceMap[code] = AKKeyCode1;
		} else if ([[b name] isEqualToString:@"p1 up"]) {
			_deviceToVirtualMap[AKKeyCodeUpArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeUpArrow;
		} else if ([[b name] isEqualToString:@"p1 down"]) {
			_deviceToVirtualMap[AKKeyCodeDownArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeDownArrow;
		} else if ([[b name] isEqualToString:@"p1 left"]) {
			_deviceToVirtualMap[AKKeyCodeLeftArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeLeftArrow;
		} else if ([[b name] isEqualToString:@"p1 right"]) {
			_deviceToVirtualMap[AKKeyCodeRightArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeRightArrow;
		} else if ([[b name] isEqualToString:@"p1 fire 1"]) {
			_deviceToVirtualMap[AKKeyCodeA] = code;
			_virtualToDeviceMap[code] = AKKeyCodeA;
		} else if ([[b name] isEqualToString:@"p1 fire 2"]) {
			_deviceToVirtualMap[AKKeyCodeS] = code;
			_virtualToDeviceMap[code] = AKKeyCodeS;
		} else if ([[b name] isEqualToString:@"p1 fire 3"]) {
			_deviceToVirtualMap[AKKeyCodeD] = code;
			_virtualToDeviceMap[code] = AKKeyCodeD;
		} else if ([[b name] isEqualToString:@"p1 fire 4"]) {
			_deviceToVirtualMap[AKKeyCodeF] = code;
			_virtualToDeviceMap[code] = AKKeyCodeF;
		} else {
			NSLog(@"unrecognized code: %@", [b name]);
		}
	}];
}

- (void) restoreStreetFighterDefaults:(FXDriver *) driver
{
	[[driver buttons] enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		if (idx > 255) {
			*stop = YES;
			return;
		}

		int code = [b code]; // (int) idx + 1;
		if ([[b name] isEqualToString:@"p1 coin"]) {
			_deviceToVirtualMap[AKKeyCode5] = code;
			_virtualToDeviceMap[code] = AKKeyCode5;
		} else if ([[b name] isEqualToString:@"p1 start"]) {
			_deviceToVirtualMap[AKKeyCode1] = code;
			_virtualToDeviceMap[code] = AKKeyCode1;
		} else if ([[b name] isEqualToString:@"p1 up"]) {
			_deviceToVirtualMap[AKKeyCodeUpArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeUpArrow;
		} else if ([[b name] isEqualToString:@"p1 down"]) {
			_deviceToVirtualMap[AKKeyCodeDownArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeDownArrow;
		} else if ([[b name] isEqualToString:@"p1 left"]) {
			_deviceToVirtualMap[AKKeyCodeLeftArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeLeftArrow;
		} else if ([[b name] isEqualToString:@"p1 right"]) {
			_deviceToVirtualMap[AKKeyCodeRightArrow] = code;
			_virtualToDeviceMap[code] = AKKeyCodeRightArrow;
		} else if ([[b name] isEqualToString:@"p1 fire 1"]) {
			_deviceToVirtualMap[AKKeyCodeA] = code;
			_virtualToDeviceMap[code] = AKKeyCodeA;
		} else if ([[b name] isEqualToString:@"p1 fire 2"]) {
			_deviceToVirtualMap[AKKeyCodeS] = code;
			_virtualToDeviceMap[code] = AKKeyCodeS;
		} else if ([[b name] isEqualToString:@"p1 fire 3"]) {
			_deviceToVirtualMap[AKKeyCodeD] = code;
			_virtualToDeviceMap[code] = AKKeyCodeD;
		} else if ([[b name] isEqualToString:@"p1 fire 4"]) {
			_deviceToVirtualMap[AKKeyCodeZ] = code;
			_virtualToDeviceMap[code] = AKKeyCodeZ;
		} else if ([[b name] isEqualToString:@"p1 fire 5"]) {
			_deviceToVirtualMap[AKKeyCodeX] = code;
			_virtualToDeviceMap[code] = AKKeyCodeX;
		} else if ([[b name] isEqualToString:@"p1 fire 6"]) {
			_deviceToVirtualMap[AKKeyCodeC] = code;
			_virtualToDeviceMap[code] = AKKeyCodeC;
		} else {
			NSLog(@"unrecognized code: %@", [b name]);
		}
	}];
}

@end
