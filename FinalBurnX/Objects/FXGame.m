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
#import "FXGame.h"

@implementation FXGame

#pragma mark - NSCoding

- (instancetype) initWithCoder:(NSCoder *) coder
{
    if ((self = [super init]) != nil) {
        self->_archive = [coder decodeObjectForKey:@"archive"];
		self->_driver = [coder decodeIntegerForKey:@"driver"];
		self->_width = [coder decodeIntegerForKey:@"width"];
		self->_height = [coder decodeIntegerForKey:@"height"];
		self->_system = [coder decodeObjectForKey:@"system"];
		self->_title = [coder decodeObjectForKey:@"title"];
		self->_parent = [coder decodeObjectForKey:@"parent"];
    }
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[coder encodeObject:self->_archive forKey:@"archive"];
	[coder encodeInteger:self->_driver forKey:@"driver"];
	[coder encodeInteger:self->_width forKey:@"width"];
	[coder encodeInteger:self->_height forKey:@"height"];
	[coder encodeObject:self->_system forKey:@"system"];
	[coder encodeObject:self->_title forKey:@"title"];
	[coder encodeObject:self->_parent forKey:@"parent"];
}

@end
