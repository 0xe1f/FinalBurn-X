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
#import "FXGameConfig.h"

#import "FXButtonMap.h"

@implementation FXGameConfig

#pragma mark - init, dealloc

- (instancetype) init
{
	if (self = [super init]) {
		_keyboardMap = [FXButtonMap new];
		_joyMaps = [NSMutableDictionary dictionary];
	}

	return self;
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if ((self = [super init]) != nil) {
		_keyboardMap = [coder decodeObjectForKey:@"keyMap"];
		_joyMaps = [coder decodeObjectForKey:@"joyMaps"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[coder encodeObject:_keyboardMap forKey:@"keyMap"];
	[coder encodeObject:_joyMaps forKey:@"joyMaps"];
}

@end
