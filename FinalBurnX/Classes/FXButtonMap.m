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

@interface FXButtonMap ()

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

- (int) deviceCodeMatching:(int) code
{
	if (code < 0 || code >= MAP_SIZE) {
		return FXMappingNotFound;
	}

	return _virtualToDeviceMap[code];
}

- (BOOL) mapDeviceCode:(int) deviceCode
		   virtualCode:(int) virtualCode
{
	if (deviceCode < 0 || deviceCode >= MAP_SIZE
		|| virtualCode < 0 || virtualCode >= MAP_SIZE) {
		return NO;
	}

	_deviceToVirtualMap[deviceCode] = virtualCode;
	_virtualToDeviceMap[virtualCode] = deviceCode;
	_dirty = YES;

	return YES;
}

- (void) markClean
{
	_dirty = NO;
}

#pragma mark - Private

- (void) resetAll
{
	memset(&_deviceToVirtualMap, 0xff, sizeof(_deviceToVirtualMap));
	memset(&_virtualToDeviceMap, 0xff, sizeof(_virtualToDeviceMap));
}

@end
