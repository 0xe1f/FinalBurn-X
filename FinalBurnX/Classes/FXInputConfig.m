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

@implementation FXInputConfig

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
		_keyboard = [coder decodeObjectForKey:@"keyboard"];
		_gamepads = [coder decodeObjectForKey:@"gamepads"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[coder encodeObject:_keyboard forKey:@"keyboard"];
	[coder encodeObject:_gamepads forKey:@"gamepads"];
}

@end
