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
