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
#import "FXGameController.h"

#import "AKKeyboardManager.h"
#import "FXAppDelegate.h"
#import "FXInputMap.h"

@interface FXGameController ()

- (NSSize) preferredSizeOfScreenWithSize:(NSSize) screenSize;
- (void) scaleScreen:(CGFloat) factor;
- (void) windowKeyDidChange:(BOOL) isKey;
- (void) resizeFrame:(NSSize) newSize
			 animate:(BOOL) animate;
- (void) autoMapInput;

@end

@implementation FXGameController
{
	NSString *_archive;
	NSDictionary *_driverInfo;
	NSSize _screenSize;
	FXInputMap *_inputMap;
}

- (instancetype) initWithArchive:(NSString *) archive
{
    if ((self = [super initWithWindowNibName:@"Game"])) {
		self->_archive = archive;
		self->_inputMap = [[FXInputMap alloc] init];
    }
    
    return self;
}

- (void) awakeFromNib
{
	self->_driverInfo = [[[FXAppDelegate sharedInstance] sets] objectForKey:self->_archive];
	
	NSInteger screenWidth = [[self->_driverInfo objectForKey:@"width"] intValue];
	NSInteger screenHeight = [[self->_driverInfo objectForKey:@"height"] intValue];
	NSString *attrs = [self->_driverInfo objectForKey:@"attrs"];
	
	self->_screenSize = NSMakeSize(screenWidth, screenHeight);
	
	[[self window] setTitle:[self->_driverInfo objectForKey:@"title"]];
	
	[self->wrapper setUpWithArchive:self->_archive
								uid:nil];
	
	[self->screen setScreenWidth:screenWidth];
	[self->screen setScreenHeight:screenHeight];
	[self->screen setScreenFlipped:[attrs containsString:@"flipped"]];
	[self->screen setScreenRotated:[attrs containsString:@"rotated"]];
	
	[self autoMapInput];
}

- (void) autoMapInput
{
	// FIXME
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^p(\\d) (.*?)( \\d+)?$"
																		   options:NSRegularExpressionCaseInsensitive
																			 error:NULL];
	
	[[self->_driverInfo objectForKey:@"input"] enumerateKeysAndObjectsUsingBlock:^(NSString *code, NSDictionary *values, BOOL *stop) {
		NSUInteger virtualCode = [[values objectForKey:@"code"] integerValue];
		if ([code isEqualToString:@"diag"]) {
			[self->_inputMap mapKeyCode:AKKeyCodeF2
						  toVirtualCode:virtualCode];
			return;
		}
		
		[regex enumerateMatchesInString:code
								options:0
								  range:NSMakeRange(0, [code length])
							 usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
								 NSUInteger player = [[code substringWithRange:[match rangeAtIndex:1]] integerValue];
								 NSString *desc = [code substringWithRange:[match rangeAtIndex:2]];
								 
								 if ([desc isEqualToString:@"coin"]) {
									 [self->_inputMap mapKeyCode:AKKeyCode5 + (player - 1)
												   toVirtualCode:virtualCode];
								 } else if ([desc isEqualToString:@"start"]) {
									 [self->_inputMap mapKeyCode:AKKeyCode1 + (player - 1)
												   toVirtualCode:virtualCode];
								 } else if (player == 1) {
									 if ([desc isEqualToString:@"left"]) {
										 [self->_inputMap mapKeyCode:AKKeyCodeLeftArrow
													   toVirtualCode:virtualCode];
									 } else if ([desc isEqualToString:@"right"]) {
										 [self->_inputMap mapKeyCode:AKKeyCodeRightArrow
													   toVirtualCode:virtualCode];
									 } else if ([desc isEqualToString:@"up"]) {
										 [self->_inputMap mapKeyCode:AKKeyCodeUpArrow
													   toVirtualCode:virtualCode];
									 } else if ([desc isEqualToString:@"down"]) {
										 [self->_inputMap mapKeyCode:AKKeyCodeDownArrow
													   toVirtualCode:virtualCode];
									 } else if ([desc isEqualToString:@"fire"]) {
										 NSUInteger button = [[code substringWithRange:[match rangeAtIndex:3]] integerValue];
										 NSUInteger key;
										 if (button <= 3) {
											 key = AKKeyCodeA + (button - 1);
										 } else if (button <= 6) {
											 key = AKKeyCodeZ + (button - 4);
										 }
										 
										 [self->_inputMap mapKeyCode:key
													   toVirtualCode:virtualCode];
									 }
								 }
							 }];
	}];
}

#pragma mark - NSWindowDelegate

- (void) windowDidBecomeKey:(NSNotification *) notification
{
    [self windowKeyDidChange:YES];
}

- (void) windowDidResignKey:(NSNotification *) notification
{
    [self windowKeyDidChange:NO];
}

- (void) keyDown:(NSEvent *) theEvent
{
    // Suppress the beeps
}

- (NSSize) windowWillResize:(NSWindow *)sender
					 toSize:(NSSize)frameSize
{
	if (self->_screenSize.width != 0 && self->_screenSize.height != 0) {
		NSRect windowFrame = [[self window] frame];
		NSRect viewRect = [self->screen convertRect:[self->screen bounds]
											 toView: nil];
		NSRect contentRect = [[self window] contentRectForFrameRect:windowFrame];
		
		CGFloat screenRatio = self->_screenSize.width / self->_screenSize.height;
		
		float marginY = viewRect.origin.y + windowFrame.size.height - contentRect.size.height;
		float marginX = contentRect.size.width - viewRect.size.width;
		
		// Clamp the minimum height
		if ((frameSize.height - marginY) < self->_screenSize.height) {
			frameSize.height = self->_screenSize.height + marginY;
		}
		
		// Set the screen width as a percentage of the screen height
		frameSize.width = (frameSize.height - marginY) * screenRatio + marginX;
	}

	return frameSize;
}

- (void) windowDidResize:(NSNotification *) notification
{
	if (self->_screenSize.width != 0 && self->_screenSize.height != 0) {
		NSRect windowFrame = [[self window] frame];
		NSRect contentRect = [[self window] contentRectForFrameRect:windowFrame];
		
		NSString *screenSizeString = NSStringFromSize(self->_screenSize);
		NSString *actualSizeString = NSStringFromSize(contentRect.size);
		
		[[NSUserDefaults standardUserDefaults] setObject:actualSizeString
												  forKey:[@"preferredSize-" stringByAppendingString:screenSizeString]];
		
		NSLog(@"FXEmulatorController/windowDidResize: (screen: {%.00f,%.00f}; view: {%.00f,%.00f})",
			  self->_screenSize.width, self->_screenSize.height,
			  contentRect.size.width, contentRect.size.height);
	}
}

- (void) windowWillClose:(NSNotification *) notification
{
	[self->wrapper terminate];
	
	[[FXAppDelegate sharedInstance] cleanupWindow:self->_archive];
}

#pragma mark - Actions

- (void) resizeNormalSize:(id) sender
{
	[self scaleScreen:1.0];
}

- (void) resizeDoubleSize:(id) sender
{
	[self scaleScreen:2.0];
}

- (void) pauseGameplay:(id) sender
{
	NSLog(@"FIXME: pauseGameplay");
//    [[self runLoop] setPaused:![[self runLoop] isPaused]];
}

- (void) resetEmulation:(id) sender
{
	NSLog(@"FIXME: resetEmulation");
//    [[self input] setResetPressed:YES];
}

- (void) toggleTestMode:(id) sender
{
	NSLog(@"FIXME: toggleTestMode");
//    [[self input] setTestPressed:YES];
}

#pragma mark - Private methods

- (void) scaleScreen:(CGFloat) factor
{
	if (self->_screenSize.width != 0 && self->_screenSize.height != 0) {
		[self resizeFrame:NSMakeSize(self->_screenSize.width * factor,
									 self->_screenSize.height * factor)
				  animate:YES];
	}
}

- (NSSize) preferredSizeOfScreenWithSize:(NSSize) screenSize
{
	NSString *screenSizeString = NSStringFromSize(screenSize);
	NSString *preferredSizeString = [[NSUserDefaults standardUserDefaults] objectForKey:[@"preferredSize-" stringByAppendingString:screenSizeString]];

	if (preferredSizeString != nil) {
		return NSSizeFromString(preferredSizeString);
	} else {
		// Default size is double the size of screen
		return NSMakeSize(screenSize.width * 2, screenSize.height * 2);
	}
}

- (void) resizeFrame:(NSSize) newSize
			 animate:(BOOL) animate
{
    NSRect windowRect = [[self window] frame];
    NSSize windowSize = windowRect.size;
    NSSize glViewSize = [self->screen frame].size;
    
    CGFloat newWidth = newSize.width + (windowSize.width - glViewSize.width);
    CGFloat newHeight = newSize.height + (windowSize.height - glViewSize.height);
    
    NSRect newRect = NSMakeRect(windowRect.origin.x, windowRect.origin.y,
                                newWidth, newHeight);
    
    [[self window] setFrame:newRect
                    display:YES
                    animate:animate];
}

- (void) windowKeyDidChange:(BOOL) isKey
{
	if (!isKey) {
		[[self->wrapper remoteObjectProxy] stopTrackingInput];
	} else {
		[[self->wrapper remoteObjectProxy] startTrackingInputWithMap:self->_inputMap];
	}
}

#pragma mark - NSUserInterfaceValidation

- (BOOL) validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>) item
{
    NSMenuItem *menuItem = (NSMenuItem*)item;
    
    if ([item action] == @selector(pauseGameplay:))
    {
//        if (![[self runLoop] isPaused]) {
//            [menuItem setTitle:NSLocalizedString(@"Pause", @"Gameplay")];
//        } else {
//            [menuItem setTitle:NSLocalizedString(@"Resume", @"Gameplay")];
//        }
		
        return YES;
    }
    
    return [menuItem isEnabled];
}

@end
