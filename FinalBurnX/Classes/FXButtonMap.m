/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/pokebyte/FinalBurn-X
 ** Copyright (C) 2014-2016 Akop Karapetyan
 **
 ** Licensed under the Apache License, Version 2.0 (the "License");
 ** you may not use this file except in compliance with the License.
 ** You may obtain a copy of the License at
 **
 **     http://www.apache.org/licenses/LICENSE-2.0
 **
 ** Unless required by applicable law or agreed to in writing, software
 ** distributed under the License is distributed on an "AS IS" BASIS,
 ** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 ** See the License for the specific language governing permissions and
 ** limitations under the License.
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

		_deviceId = [coder decodeObjectForKey:@"deviceId"];
		_customized = [coder decodeBoolForKey:@"custom"];
		NSDictionary<NSNumber *, NSNumber *> *map = [coder decodeObjectForKey:@"map"];
		[map enumerateKeysAndObjectsUsingBlock:^(NSNumber *v, NSNumber *d, BOOL *stop) {
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
	[coder encodeObject:_deviceId forKey:@"deviceId"];
	[coder encodeBool:_customized forKey:@"custom"];
	[coder encodeObject:map forKey:@"map"];
}

#pragma mark - Public

- (int) virtualCodeMatching:(int) code
{
	if (code < 0 || code >= MAP_SIZE) {
		return FXMappingNotFound;
	}
	
	return _deviceToVirtualMap[code];
}

- (int) deviceCodeMatching:(int) code
{
	if (code < 0 || code >= MAP_SIZE) {
		return FXMappingNotFound;
	}
	
	return _virtualToDeviceMap[code];
}

- (int) mapDeviceCode:(int) deviceCode
		  virtualCode:(int) virtualCode
{
	if (deviceCode < -1 || deviceCode >= MAP_SIZE
		|| virtualCode < 0 || virtualCode >= MAP_SIZE) {
		return FXMappingNotFound;
	}

	_customized = YES;
	_dirty = YES;
	int currentVirtual = FXMappingNotFound;
	@synchronized (self) {
		if (deviceCode != FXMappingNotFound) {
			currentVirtual = _deviceToVirtualMap[deviceCode];
			_deviceToVirtualMap[deviceCode] = virtualCode;
		}
		if (currentVirtual != FXMappingNotFound) {
			_virtualToDeviceMap[currentVirtual] = FXMappingNotFound;
		}
		_virtualToDeviceMap[virtualCode] = deviceCode;
	}

	return currentVirtual;
}

- (void) clearDirty
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
