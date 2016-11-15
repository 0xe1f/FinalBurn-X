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
#import "FXManifest.h"

#pragma mark - FXButton

@interface FXButton ()

- (void) parseIfNeeded;

@end

@implementation FXButton
{
	BOOL _parsed;
	int _playerIndex;
	int _fireIndex;
	NSString *_neutralTitle;
}

static NSRegularExpression *regex;

+ (void) initialize
{
	regex = [NSRegularExpression regularExpressionWithPattern:@"^p(\\d) (.*?)( (\\d))?$"
													  options:NSRegularExpressionCaseInsensitive
														error:NULL];
}

- (instancetype) initWithCode:(int) code
				   dictionary:(NSDictionary *) d
{
	if (self = [super init]) {
		_fireIndex = -1;
		_playerIndex = -1;
		_name = [d objectForKey:@"name"];
		_title = [d objectForKey:@"title"];
		_code = code;
	}
	
	return self;
}

#pragma mark - Private

- (void) parseIfNeeded
{
	if (!_parsed) {
		NSTextCheckingResult *m = [regex firstMatchInString:_name
													options:0
													  range:NSMakeRange(0, [_name length])];
		
		if (m) {
			NSRange playerRange = [m rangeAtIndex:1];
			NSRange nameRange = [m rangeAtIndex:2];
			NSRange fireRange = [m rangeAtIndex:4];
			
			if (playerRange.location != NSNotFound) {
				_playerIndex = [[_name substringWithRange:playerRange] intValue];
				if ([[_name substringWithRange:nameRange] isEqualToString:@"fire"]) {
					_fireIndex = 0;
					if (fireRange.location != NSNotFound) {
						_fireIndex = [[_name substringWithRange:fireRange] intValue];
					}
				}
			}
		}

		_parsed = YES;
	}
}

#pragma mark - Public

- (BOOL) isPlayerSpecific
{
	[self parseIfNeeded];
	return _playerIndex > -1;
}

- (BOOL) isFireButton
{
	[self parseIfNeeded];
	return _fireIndex > -1;
}

- (int) playerIndex
{
	[self parseIfNeeded];
	return _playerIndex;
}

- (int) fireIndex
{
	[self parseIfNeeded];
	return _fireIndex;
}

- (NSString *) neutralTitle
{
	if (!_neutralTitle) {
		if ([_title length] > 3
			&& [_title characterAtIndex:0] == 'P'
			&& [_title characterAtIndex:2] == ' ') {
			_neutralTitle = [_title substringWithRange:NSMakeRange(3, [_title length] - 3)];
		} else {
			_neutralTitle = _title;
		}
	}

	return _neutralTitle;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ (p%d,f%d)", _name,
			[self playerIndex], [self fireIndex]];
}

@end

#pragma mark - FXDriver

@interface FXDriver ()

- (void) setParent:(FXDriver *) parent;
- (void) addChildren:(NSArray<FXDriver *> *) children;

@end

@implementation FXDriver

- (instancetype) initWithName:(NSString *) name
				   dictionary:(NSDictionary *) d
{
	if (self = [super init]) {
		_name = name;
		_index = [[d objectForKey:@"driver"] intValue];
		_title = [d objectForKey:@"title"];
		_system = [d objectForKey:@"system"];
		_children = [NSMutableArray array];
		_screenSize = NSMakeSize([[d objectForKey:@"width"] floatValue],
								 [[d objectForKey:@"height"] floatValue]);

		NSMutableArray<FXButton *> *buttons = [NSMutableArray array];
		_buttons = buttons;
		[[d objectForKey:@"input"] enumerateObjectsUsingBlock:^(NSDictionary *idict, NSUInteger idx, BOOL *stop) {
			[buttons addObject:[[FXButton alloc] initWithCode:(int) idx + 1
												   dictionary:idict]];
		}];
	}

	return self;
}

- (void) setParent:(FXDriver *) parent
{
	_parent = parent;
}

- (void) addChildren:(NSArray<FXDriver *> *) children
{
	[(NSMutableArray *) _children addObjectsFromArray:children];
}

- (BOOL) usesStreetFighterLayout
{
	if (![_system hasPrefix:@"CPS"]) {
		return NO;
	}

	return [self fireButtonCount] >= 6;
}

- (int) fireButtonCount
{
	__block int count = 0;
	[_buttons enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		if ([b playerIndex] == 1 && [b isFireButton]) {
			count++;
		}
	}];

	return count;
}

@end

#pragma mark - FXManifest

@interface FXManifest ()

- (void) scanPlist:(NSString *) path;

@end

@implementation FXManifest
{
	NSMutableDictionary<NSString *, FXDriver *> *_driverMap;
}

#pragma mark - Init, dealloc

- (instancetype) init
{
    if (self = [super init]) {
		_driverMap = [NSMutableDictionary dictionary];
		_drivers = [NSMutableArray array];

		[self scanPlist:[[NSBundle mainBundle] pathForResource:@"SetManifest"
														ofType:@"plist"]];
    }
    return self;
}

#pragma mark - Singleton

+ (FXManifest *) sharedInstance
{
	static dispatch_once_t onceToken;
	static FXManifest *sharedInstance = nil;

	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});

	return sharedInstance;
}

#pragma mark - Public

- (FXDriver *) driverNamed:(NSString *) name
{
	return [_driverMap objectForKey:name];
}

#pragma mark - Private

- (void) scanPlist:(NSString *) path
{
	NSMutableDictionary *childMap = [NSMutableDictionary dictionary];

	// Load list of drivers
	NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:path];
	[m enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *d, BOOL *stop) {
		FXDriver *driver = [[FXDriver alloc] initWithName:name
											   dictionary:d];

		NSString *parentName = [d objectForKey:@"parent"];
		if (parentName) {
			NSMutableArray *children = [childMap objectForKey:parentName];
			if (!children) {
				children = [NSMutableArray array];
				[childMap setObject:children
							 forKey:parentName];
			}

			[children addObject:driver];
		} else {
			[(NSMutableArray *) _drivers addObject:driver];
		}

		[_driverMap setObject:driver
					   forKey:name];
	}];

	// Initialize parent references
	[childMap enumerateKeysAndObjectsUsingBlock:^(NSString *parent, NSArray *children, BOOL *stop) {
		FXDriver *pd = [_driverMap objectForKey:parent];
		[pd addChildren:children];
		[children enumerateObjectsUsingBlock:^(FXDriver *cd, NSUInteger idx, BOOL *stop) {
			[cd setParent:pd];
		}];
	}];
}

@end
