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
#import "FXGame.h"
#import "FXInputState.h"

@interface FXGameController ()

- (NSSize) preferredSizeOfScreenWithSize:(NSSize) screenSize;
- (void) scaleScreen:(CGFloat) factor;
- (void) windowKeyDidChange:(BOOL) isKey;
- (void) resizeFrame:(NSSize) newSize
			 animate:(BOOL) animate;

@end

@implementation FXGameController
{
	NSString *_archive;
	FXGame *_game;
	NSSize _screenSize;
	FXInputState *_inputState;
}

- (instancetype) initWithArchive:(NSString *) archive
{
    if ((self = [super initWithWindowNibName:@"Game"])) {
		self->_archive = archive;
		self->_inputState = [[FXInputState alloc] init];
    }
    
    return self;
}

- (void) awakeFromNib
{
	self->_game = [[[FXAppDelegate sharedInstance] games] objectForKey:self->_archive];
	self->_screenSize = NSMakeSize([self->_game width], [self->_game height]);
	
	[[self window] setTitle:[self->_game title]];
	
	[self->wrapper setUpWithArchive:self->_archive
								uid:nil];
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

#pragma mark - AKKeyboardEventDelegate

- (NSInteger) foo:(NSInteger) keyCode
{
	int from[] = {
		AKKeyCode5,
		AKKeyCode1,
		AKKeyCodeUpArrow,
		AKKeyCodeDownArrow,
		AKKeyCodeLeftArrow,
		AKKeyCodeRightArrow,
		AKKeyCodeA,
		AKKeyCodeS,
		AKKeyCodeD,
		AKKeyCodeZ,
		AKKeyCodeX,
		AKKeyCodeC,
		-1
	};
	int to[] = {
		1,
		2,
		3,
		4,
		5,
		6,
		7,
		8,
		9,
		10,
		11,
		12,
		-1
	};
	
	for (int i = 0; from[i] != -1; i++) {
		if (from[i] == keyCode) {
			return to[i];
		}
	}
	
	return -1;
}

- (void) keyStateChanged:(AKKeyEventData *) event
				  isDown:(BOOL) isDown
{
#ifdef DEBUG_KEY_STATE
	if (isDown) {
		NSLog(@"keyboardKeyDown: 0x%lx", [event keyCode]);
	} else {
		NSLog(@"keyboardKeyUp: 0x%lx", [event keyCode]);
	}
#endif
	
	// Don't generate a KeyDown if Command is pressed
	if (([event modifierFlags] & NSCommandKeyMask) == 0 || !isDown) {
		NSInteger fbk = [self foo:[event keyCode]];
		if (fbk != -1) {
			[self->_inputState setStateForCode:fbk
									 isPressed:isDown];
			[[self->wrapper remoteObjectProxy] updateInput:self->_inputState];
		}
	}
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
#ifdef DEBUG
		NSLog(@"GameController/-Focus");
#endif
		// Emulator has lost focus - release all virtual keys
		[self->_inputState releaseAll];
		[[self->wrapper remoteObjectProxy] updateInput:self->_inputState];
		
		// Stop listening for key events
		[[AKKeyboardManager sharedInstance] removeObserver:self];
	} else {
#ifdef DEBUG
		NSLog(@"GameController/+Focus");
#endif
		// Start listening for key events
		[[AKKeyboardManager sharedInstance] addObserver:self];
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
