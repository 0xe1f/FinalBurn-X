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
#import "FXManifest.h"

#pragma mark - FXButton

@implementation FXButton

- (instancetype) initWithName:(NSString *) name
				   dictionary:(NSDictionary *) d
{
	if (self = [super init]) {
		_name = name;
		_title = [d objectForKey:@"title"];
		_code = [[d objectForKey:@"code"] intValue];
	}
	
	return self;
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
		[[d objectForKey:@"input"] enumerateKeysAndObjectsUsingBlock:^(NSString *iname, NSDictionary *idict, BOOL *stop) {
			[buttons addObject:[[FXButton alloc] initWithName:iname
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

- (NSString *) description
{
	if (_parent) {
		return [NSString stringWithFormat:@"%@/%@", _parent->_name, _name];
	}

	return _name;
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
