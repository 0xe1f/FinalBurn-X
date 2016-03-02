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
#import "FXInputMap.h"

@implementation FXInputMap
{
	// NOTE: this class assumes that virtualCode of 0 means the input is
	// unmapped
	NSUInteger _keyMap[256];
}

- (instancetype) init
{
	if ((self = [super init])) {
		memset(self->_keyMap, 0, sizeof(self->_keyMap));
	}
	
	return self;
}

- (void) clear
{
	memset(self->_keyMap, 0, sizeof(self->_keyMap));
}

- (void) mapKeyCode:(NSUInteger) keyCode
	  toVirtualCode:(NSUInteger) inputCode
{
	if (keyCode < 256) {
		self->_keyMap[keyCode] = inputCode;
	}
}

- (NSUInteger) virtualCodeForKeyCode:(NSUInteger) keyCode
{
	if (keyCode < 256) {
		return self->_keyMap[keyCode];
	}
	
	return 0;
}

#pragma mark - NSSecureCoding

+ (BOOL) supportsSecureCoding
{
	return YES;
}

- (instancetype) initWithCoder:(NSCoder *) coder
{
    if ((self = [super init]) != nil) {
		NSData *data = [coder decodeObjectOfClass:[NSData class]
										   forKey:@"keyMap"];
		[data getBytes:self->_keyMap];
    }
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	NSData *data = [NSData dataWithBytes:self->_keyMap
								  length:sizeof(self->_keyMap)];
	[coder encodeObject:data
				 forKey:@"keyMap"];
}

@end
