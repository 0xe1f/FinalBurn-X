/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) Akop Karapetyan
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
#import "FXInputConfig.h"

#import "FXButtonMap.h"

@implementation FXInputConfig
{
	NSMutableDictionary<NSString *, FXButtonMap *> *_maps;
}

#pragma mark - init, dealloc

- (instancetype) init
{
	if (self = [super init]) {
		_maps = [NSMutableDictionary new];
	}

	return self;
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if ((self = [super init])) {
		NSArray<FXButtonMap *> *maps = [coder decodeObjectForKey:@"gamepads"];

		_maps = [NSMutableDictionary new];
		[maps enumerateObjectsUsingBlock:^(FXButtonMap *bm, NSUInteger idx, BOOL *stop) {
			[_maps setObject:bm forKey:[bm deviceId]];
		}];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	NSMutableArray<FXButtonMap *> *maps = [NSMutableArray array];
	[_maps enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *bm, BOOL *stop) {
		if ([bm customized]) {
			[maps addObject:bm];
		}
	}];

	[coder encodeObject:maps forKey:@"gamepads"];
}

#pragma mark - Public

- (FXButtonMap *) mapWithId:(NSString *) mapId
{
	return [_maps objectForKey:mapId];
}

- (void) setMap:(FXButtonMap *) map
{
	[_maps setObject:map forKey:[map deviceId]];
}

- (BOOL) dirty
{
	__block BOOL isDirty = NO;
	[_maps enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *map, BOOL *stop) {
		if ([map dirty]) {
			isDirty = YES;
			*stop = YES;
		}
	}];

	return isDirty;
}

- (void) clearDirty
{
	[_maps enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *map, BOOL *stop) {
		[map clearDirty];
	}];
}

@end
