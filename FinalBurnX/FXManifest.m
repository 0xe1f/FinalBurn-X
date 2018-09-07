/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
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

#import "FXZipArchive.h"

#pragma mark - FXDIPOption

@interface FXDIPOption ()

@end

@implementation FXDIPOption

- (instancetype) initWithDictionary:(NSDictionary *) d
{
	if (self = [super init]) {
		_title = [d objectForKey:@"name"];
		_mask = [[d objectForKey:@"mask"] unsignedLongValue];
		_setting = [[d objectForKey:@"setting"] unsignedLongValue];
		_start = [[d objectForKey:@"start"] unsignedIntValue];
	}
	
	return self;
}

@end

#pragma mark - FXDIPGroup

@interface FXDIPGroup ()

@end

@implementation FXDIPGroup

- (instancetype) initWithDictionary:(NSDictionary *) d
{
	if (self = [super init]) {
		_title = [d objectForKey:@"name"];
		_selection = -1;

		NSMutableArray *options = [NSMutableArray array];
		[[d objectForKey:@"items"] enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
			FXDIPOption *option = [[FXDIPOption alloc] initWithDictionary:obj];
			[options addObject:option];

			if ([[obj objectForKey:@"default"] boolValue]) {
				_selection = idx;
			} else if ([option setting] == 0 && _selection == -1) {
				_selection = idx;
			}
		}];

		if (_selection == -1) {
			_selection = 0;
		}

		_options = [NSArray arrayWithArray:options];
	}
	
	return self;
}

@end

#pragma mark - FXButton

@interface FXButton ()

- (void) parseIfNeeded;

@end

@implementation FXButton
{
	BOOL _parsed;
	int _playerIndex;
	int _fireIndex;
	NSString *_neutralName;
	NSString *_neutralTitle;
}

static NSRegularExpression *regex;

+ (void) initialize
{
	regex = [NSRegularExpression regularExpressionWithPattern:@"^p(\\d) ((.*?)( (\\d))?)$"
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
			NSRange fireRange = [m rangeAtIndex:5];
			
			if (playerRange.location != NSNotFound) {
				_playerIndex = [[_name substringWithRange:playerRange] intValue];
				_neutralName = [_name substringWithRange:[m rangeAtIndex:2]];
				if ([[_name substringWithRange:[m rangeAtIndex:3]] isEqualToString:@"fire"]) {
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

- (NSString *) neutralName
{
	[self parseIfNeeded];
	return _neutralName;
}

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

#pragma mark - FXDriverFile

@implementation FXDriverFile

- (instancetype) initWithName:(NSString *) name
				   dictionary:(NSDictionary *) dict
{
	if (self = [super init]) {
		_name = name;
		_crc = (UInt32) [[dict objectForKey:@"crc"] unsignedIntValue];
		_length = [[dict objectForKey:@"len"] unsignedIntValue];
	}
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ (crc:0x%x,len:%d)", _name, _crc, _length];
}

- (BOOL) isEqual:(id) other
{
	if (other == self) {
		return YES;
	} else if (![super isEqual:other]) {
		return NO;
	} else {
		return [_name isEqual:[other name]];
	}
}

- (NSUInteger) hash
{
	return [_name hash];
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
		[[d objectForKey:@"input"] enumerateObjectsUsingBlock:^(NSDictionary *idict, NSUInteger idx, BOOL *stop) {
			[buttons addObject:[[FXButton alloc] initWithCode:(int) idx + 1
												   dictionary:idict]];
		}];
		_buttons = [NSArray arrayWithArray:buttons];

		NSMutableArray<FXDIPGroup *> *groups = [NSMutableArray array];
		[[d objectForKey:@"dipswitches"] enumerateObjectsUsingBlock:^(NSDictionary *idict, NSUInteger idx, BOOL *stop) {
			[groups addObject:[[FXDIPGroup alloc] initWithDictionary:idict]];
		}];
		_dipswitches = [NSArray arrayWithArray:groups];

		NSDictionary *fileRoot = [d objectForKey:@"files"];
		NSMutableDictionary<NSString *, FXDriverFile *> *files = [NSMutableDictionary dictionary];
		[[fileRoot objectForKey:@"local"] enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *stats, BOOL *stop) {
			[files setObject:[[FXDriverFile alloc] initWithName:name
													 dictionary:stats]
					  forKey:name];
		}];
		_files = [NSDictionary dictionaryWithDictionary:files];

		NSArray *parentFiles = [fileRoot objectForKey:@"parent"];
		if (parentFiles) {
			_parentFiles = [NSArray arrayWithArray:parentFiles];
		}
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
