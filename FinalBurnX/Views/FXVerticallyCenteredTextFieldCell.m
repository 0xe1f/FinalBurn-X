/*****************************************************************************
 **
 ** CocoaMSX: MSX Emulator for Mac OS X
 ** http://www.cocoamsx.com
 ** Copyright (C) 2013 Akop Karapetyan
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
#import "FXVerticallyCenteredTextFieldCell.h"

@implementation FXVerticallyCenteredTextFieldCell

#pragma mark - NSTextFieldCell

- (NSRect) titleRectForBounds:(NSRect) frame
{
	// http://stackoverflow.com/a/33788973/132628
	CGFloat stringHeight = [[self attributedStringValue] size].height;
	NSRect titleRect = [super titleRectForBounds:frame];
	
	CGFloat oldOriginY = frame.origin.y;
	titleRect.origin.y = oldOriginY + (frame.size.height - stringHeight) / 2.0;
	titleRect.size.height = titleRect.size.height - (titleRect.origin.y - oldOriginY);
	
	return titleRect;
}

- (void) drawInteriorWithFrame:(NSRect) cFrame
						inView:(NSView *) cView
{
	[super drawInteriorWithFrame:[self titleRectForBounds:cFrame]
						  inView:cView];
}

@end
