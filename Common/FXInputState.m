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
#import "FXInputState.h"

@implementation FXInputState
{
	NSMutableData *_inputState;
}

- (instancetype) init
{
	if ((self = [super init]) != nil) {
		self->_inputState = [[NSMutableData alloc] initWithLength:256];
		memset([self->_inputState mutableBytes], 0, [self->_inputState length]);
	}
	return self;
}

- (void) setStateForCode:(NSUInteger) code
			   isPressed:(BOOL) isPressed
{
	if (code < 256) {
		unsigned char *buffer = [self->_inputState mutableBytes];
		buffer[code] = isPressed;
	}
}

- (void) releaseAll
{
	memset([self->_inputState mutableBytes], 0, [self->_inputState length]);
}

- (void) copyToBuffer:(void *) buffer
			 maxBytes:(NSUInteger) maxBytes
{
	[self->_inputState getBytes:buffer
						 length:maxBytes];
}

#pragma mark - NSSecureCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
	if ((self = [super init]) != nil) {
		self->_inputState = [[coder decodeObjectOfClass:[NSData class]
												 forKey:@"state"] mutableCopy];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[coder encodeObject:self->_inputState
				 forKey:@"state"];
}

+ (BOOL) supportsSecureCoding
{
	return YES;
}

@end
