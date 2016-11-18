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
#import "FXInputConfig.h"

#import "FXButtonMap.h"

@implementation FXInputConfig
{
	NSMutableDictionary<NSString *, FXButtonMap *> *_gamepads;
}

#pragma mark - init, dealloc

- (instancetype) init
{
	if (self = [super init]) {
		_gamepads = [NSMutableDictionary new];
	}

	return self;
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if ((self = [super init])) {
		NSArray<FXButtonMap *> *gamepads = [coder decodeObjectForKey:@"gamepads"];

		_gamepads = [NSMutableDictionary new];
		[gamepads enumerateObjectsUsingBlock:^(FXButtonMap *bm, NSUInteger idx, BOOL *stop) {
			[_gamepads setObject:bm forKey:[bm deviceId]];
		}];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	NSMutableArray<FXButtonMap *> *gamepads = [NSMutableArray array];
	[_gamepads enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *bm, BOOL *stop) {
		if ([bm customized]) {
			[gamepads addObject:bm];
		}
	}];

	[coder encodeObject:gamepads forKey:@"gamepads"];
}

#pragma mark - Public

- (FXButtonMap *) mapWithId:(NSString *) mapId
{
	return [_gamepads objectForKey:mapId];
}

- (void) setMap:(FXButtonMap *) map
{
	[_gamepads setObject:map forKey:[map deviceId]];
}

- (BOOL) dirty
{
	__block BOOL isDirty = NO;
	[_gamepads enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *map, BOOL *stop) {
		if ([map dirty]) {
			isDirty = YES;
			*stop = YES;
		}
	}];

	return isDirty;
}

- (void) clearDirty
{
	[_gamepads enumerateKeysAndObjectsUsingBlock:^(NSString *key, FXButtonMap *map, BOOL *stop) {
		[map clearDirty];
	}];
}

@end
