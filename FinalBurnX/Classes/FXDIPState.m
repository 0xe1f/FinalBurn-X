/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2017 Akop Karapetyan
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
#import "FXDIPState.h"

#import "FXManifest.h"

#define VERSION 0

NSString *const FXDIPStateChanged = @"org.akop.fbx.DIPStateChanged";

@implementation FXDIPState
{
	NSMutableDictionary<NSNumber *, NSNumber *> *_states;
	int _version;
}

#pragma mark - init, dealloc

- (instancetype) initWithDriverName:(NSString *) name
{
	if (self = [super init]) {
		_driverName = name;
		_states = [NSMutableDictionary dictionary];
		_dirty = NO;
		_version = VERSION;
	}

	return self;
}

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if (self = [super init]) {
		_driverName = [coder decodeObjectForKey:@"archive"];
		_states = [coder decodeObjectForKey:@"states"];
		_dirty = NO;
		_version = [coder decodeIntForKey:@"version"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[coder encodeObject:_states
				 forKey:@"states"];
	[coder encodeObject:_driverName
				 forKey:@"archive"];
	[coder encodeInt:_version
			  forKey:@"version"];
}

#pragma mark - Public

- (void) reset
{
	if ([_states count] > 0) {
		[_states removeAllObjects];
		_dirty = YES;

		[[NSNotificationCenter defaultCenter] postNotificationName:FXDIPStateChanged
															object:self];
	}
}

- (void) setGroup:(NSUInteger) group
		 toOption:(NSUInteger) option
{
	[_states setObject:@(option)
				forKey:@(group)];
	_dirty = YES;

	[[NSNotificationCenter defaultCenter] postNotificationName:FXDIPStateChanged
														object:self];
}

- (NSDictionary<NSNumber *, NSNumber *> *) states
{
	return [NSDictionary dictionaryWithDictionary:_states];
}

- (void) clearDirtyFlag
{
	_dirty = NO;
}

@end
