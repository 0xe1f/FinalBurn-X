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
#import "FXEmulatorController.h"

#import "FXLoader.h"

#include "burner.h"

@interface FXEmulatorController ()

- (NSSize)preferredSizeOfScreenWithSize:(NSSize)screenSize;
- (void)windowKeyDidChange:(BOOL)isKey;
- (void)resizeFrame:(NSSize)newSize
            animate:(BOOL)animate;
- (void) displayMessage:(NSString *) message;

@end

@implementation FXEmulatorController
{
	NSTitlebarAccessoryViewController *_tbAcc;
	
	BOOL _cursorVisible;
}

- (instancetype)initWithROMSet:(FXROMSet *)romSet
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setRomSet:romSet];
        [self setInput:[[FXInput alloc] initWithROMSet:romSet]];
        [self setVideo:[[FXVideo alloc] init]];
        [self setAudio:[[FXAudio alloc] init]];
        [self setRunLoop:[[FXRunLoop alloc] initWithROMSet:romSet]];
		_cursorVisible = YES;

		[[NSUserDefaults standardUserDefaults] addObserver:self
												forKeyPath:@"audioVolume"
												   options:NSKeyValueObservingOptionNew
												   context:NULL];
	}
    
    return self;
}

- (void)awakeFromNib
{
	// Initialize title bar controller
	self->_tbAcc = [[NSTitlebarAccessoryViewController alloc] init];
	[self->_tbAcc setView:self->spinner];
	[self->_tbAcc setLayoutAttribute:NSLayoutAttributeRight];
	
    NSString *title = [[self romSet] title];
    NSSize screenSize = [[self romSet] screenSize];
    NSSize preferredSize = [self preferredSizeOfScreenWithSize:screenSize];
    
    [[self window] setTitle:title];
    [[self window] setContentSize:preferredSize];
	[[self window] setBackgroundColor:[NSColor blackColor]];
	
    [[self video] setDelegate:self->screen];
    [[self runLoop] setDelegate:self];
    
    [[self runLoop] start];
	[self->_audio setVolume:[[NSUserDefaults standardUserDefaults] integerForKey:@"audioVolume"]];
	
	[self->screen setDelegate:self];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:FXEmulatorChanged
                                                        object:self
                                                      userInfo:@{ FXROMSetInfo: [self romSet] } ];
}

- (void)dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver:self
											   forKeyPath:@"audioVolume"];
}

#pragma mark - Notifications

- (void)observeValueForKeyPath:(NSString *) keyPath
					  ofObject:(id) object
						change:(NSDictionary *) change
					   context:(void *) context
{
	if ([keyPath isEqualToString:@"audioVolume"]) {
		[self->_audio setVolume:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
	}
}

#pragma mark - FXRunLoopDelegate

- (void)loadingDidStart
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self->screen setHidden:YES];
		
		// Set up title bar spinner
		[[[self->spinner subviews] firstObject] startAnimation:self];
		[[self window] addTitlebarAccessoryViewController:self->_tbAcc];

		// Block the window from being closed (until loading completes)
		NSUInteger windowStyleMask = [[self window] styleMask];
		[[self window] setStyleMask:(windowStyleMask &~ NSClosableWindowMask)];
	});
}

- (void) loadingDidEnd:(BOOL) success
{
	dispatch_async(dispatch_get_main_queue(), ^{
		// Disable spinner
		[[[self->spinner subviews] firstObject] stopAnimation:self];
		[self->_tbAcc removeFromParentViewController];
		self->_tbAcc = nil;
		
		// Make window closable again
		NSUInteger windowStyleMask = [[self window] styleMask];
		[[self window] setStyleMask:(windowStyleMask | NSClosableWindowMask)];
		
		if (success) {
			[self->screen setHidden:NO];
		} else {
			[self displayMessage:NSLocalizedString(@"The emulator shut down unexpectedly. Game may be unsupported or unplayable.",
												   @"Error message")];
		}
	});
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [self windowKeyDidChange:YES];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self windowKeyDidChange:NO];
}

- (void)keyDown:(NSEvent *)theEvent
{
    // Suppress the beeps
}

- (void)windowWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:FXEmulatorChanged
                                                        object:self
                                                      userInfo:nil];
    
    [[self video] setDelegate:nil];
    [[self runLoop] cancel];
	
	if (!_cursorVisible) {
		[NSCursor unhide];
	}
}

- (NSSize)windowWillResize:(NSWindow *)sender
                    toSize:(NSSize)frameSize
{
    NSSize screenSize = [[self romSet] screenSize];
    if (screenSize.width == 0 || screenSize.height == 0) {
        // Screen size is not yet available
    } else {
        NSRect windowFrame = [[self window] frame];
		NSView *contentView = [[self window] contentView];
		NSRect viewRect = [contentView convertRect:[contentView bounds]
											toView:nil];
        NSRect contentRect = [[self window] contentRectForFrameRect:windowFrame];
        
        CGFloat screenRatio = screenSize.width / screenSize.height;
        
        float marginY = viewRect.origin.y + windowFrame.size.height - contentRect.size.height;
        float marginX = contentRect.size.width - viewRect.size.width;
        
        // Clamp the minimum height
        if ((frameSize.height - marginY) < screenSize.height) {
            frameSize.height = screenSize.height + marginY;
        }
        
        // Set the screen width as a percentage of the screen height
        frameSize.width = (frameSize.height - marginY) * screenRatio + marginX;
    }
    
    return frameSize;
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSSize screenSize = [[self romSet] screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        NSRect windowFrame = [[self window] frame];
        NSRect contentRect = [[self window] contentRectForFrameRect:windowFrame];
        
        NSString *screenSizeString = NSStringFromSize(screenSize);
        NSString *actualSizeString = NSStringFromSize(contentRect.size);
        
        [[NSUserDefaults standardUserDefaults] setObject:actualSizeString
                                                  forKey:[@"preferredSize-" stringByAppendingString:screenSizeString]];
        
        NSLog(@"FXEmulatorController/windowDidResize: (screen: {%.00f,%.00f}; view: {%.00f,%.00f})",
              screenSize.width, screenSize.height,
              contentRect.size.width, contentRect.size.height);
    }
}

#pragma mark - Actions

- (void)resizeNormalSize:(id)sender
{
    NSSize screenSize = [[self romSet] screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        [self resizeFrame:screenSize
                  animate:YES];
    }
}

- (void)resizeDoubleSize:(id)sender
{
    NSSize screenSize = [[self romSet] screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        NSSize doubleSize = NSMakeSize(screenSize.width * 2, screenSize.height * 2);
        [self resizeFrame:doubleSize
                  animate:YES];
    }
}

- (void)pauseGameplay:(id)sender
{
    [[self runLoop] setPaused:![[self runLoop] isPaused]];
}

- (void)resetEmulation:(id)sender
{
    [[self input] setResetPressed:YES];
}

- (void)toggleTestMode:(id)sender
{
    [[self input] setTestPressed:YES];
}

#pragma mark - Core

+ (void)initializeCore
{
    BurnLibInit();
}

+ (void)cleanupCore
{
    BurnLibExit();
}

- (void)saveSettings
{
    [[self input] save];
}

- (void)restoreSettings
{
    [[self input] restore];
}

#pragma mark - Private methods

- (void) displayMessage:(NSString *) message
{
	@synchronized(self->messagePane) {
		NSTextField *label = [[self->messagePane subviews] firstObject];
		[label setStringValue:message];
		
		if (![self->messagePane superview]) {
			[self->messagePane setFrame:[self->screen frame]];
			[self->messagePane setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
			
			[label setFrame:[self->messagePane bounds]];
			[label setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
			
			NSView *contentView = [[self window] contentView];
			[contentView addSubview:messagePane];
		}
	}
}

- (NSSize)preferredSizeOfScreenWithSize:(NSSize)screenSize
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

- (void)resizeFrame:(NSSize)newSize
            animate:(BOOL)animate
{
    NSRect windowRect = [[self window] frame];
    NSSize windowSize = windowRect.size;
    NSSize glViewSize = [[[self window] contentView] bounds].size;
    
    CGFloat newWidth = newSize.width + (windowSize.width - glViewSize.width);
    CGFloat newHeight = newSize.height + (windowSize.height - glViewSize.height);
    
    NSRect newRect = NSMakeRect(windowRect.origin.x, windowRect.origin.y,
                                newWidth, newHeight);
    
    [[self window] setFrame:newRect
                    display:YES
                    animate:animate];
}

- (void)windowKeyDidChange:(BOOL)isKey
{
    [[self input] setFocus:isKey];
}

#pragma mark - NSUserInterfaceValidation

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    NSMenuItem *menuItem = (NSMenuItem*)item;
    
    if ([item action] == @selector(pauseGameplay:))
    {
        if (![[self runLoop] isPaused]) {
            [menuItem setTitle:NSLocalizedString(@"Pause", @"Gameplay")];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Resume", @"Gameplay")];
        }
        
        return YES;
    }
    
    return [menuItem isEnabled];
}

#pragma mark - FXScreenViewDelegate

- (void) mouseDidIdle
{
	if (_cursorVisible) {
		_cursorVisible = NO;
		[NSCursor hide];
	}
}

- (void) mouseStateDidChange
{
	if (!_cursorVisible) {
		_cursorVisible = YES;
		[NSCursor unhide];
	}
}

@end
