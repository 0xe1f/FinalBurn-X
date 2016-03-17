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
#import "FXEmulationState.h"

@interface FXGameController ()

- (NSSize) preferredSizeOfScreenWithSize:(NSSize) screenSize;
- (void) scaleScreen:(CGFloat) factor;
- (void) resizeFrame:(NSSize) newSize
			 animate:(BOOL) animate;
- (void) autoMapInput;
- (void) setupIOSurface;

// Actions
- (void) statusUpdate:(id) sender;

@end

@implementation FXGameController
{
	NSString *_archive;
	NSDictionary *_driverInfo;
	NSSize _screenSize;
	FXInputMap *_inputMap;
	FXEmulationState *_state;
	NSTimer *_statusTimer;
	NSTitlebarAccessoryViewController *_tbAcc;
	BOOL _pausedOnUnfocus;
}

- (instancetype) initWithArchive:(NSString *) archive
{
    if ((self = [super initWithWindowNibName:@"Game"])) {
		self->_archive = archive;
		self->_inputMap = [[FXInputMap alloc] init];
		self->_state = [[FXEmulationState alloc] init];
		self->_statusTimer = [NSTimer timerWithTimeInterval:0.5
													 target:self
												   selector:@selector(statusUpdate:)
												   userInfo:nil
													repeats:YES];
    }
    
    return self;
}

- (void) awakeFromNib
{
	self->_driverInfo = [[[FXAppDelegate sharedInstance] setManifest] objectForKey:self->_archive];
	
	NSString *attrs = [self->_driverInfo objectForKey:@"attrs"];
	
	// Set title and size
	[[self window] setTitle:[self->_driverInfo objectForKey:@"title"]];
	
	NSInteger screenWidth = [[self->_driverInfo objectForKey:@"width"] intValue];
	NSInteger screenHeight = [[self->_driverInfo objectForKey:@"height"] intValue];
	self->_screenSize = NSMakeSize(screenWidth, screenHeight);
	[self resizeFrame:[self preferredSizeOfScreenWithSize:self->_screenSize]
			  animate:YES];
	
	// Initialize process wrapper
	[self->wrapper setUpWithArchive:self->_archive
								uid:nil];
	
	// Initialize screen
	[self->screen setScreenWidth:screenWidth];
	[self->screen setScreenHeight:screenHeight];
	[self->screen setScreenFlipped:[attrs containsString:@"flipped"]];
	[self->screen setScreenRotated:[attrs containsString:@"rotated"]];
	
	// FIXME: set up a basic mapping
	[self autoMapInput];
	
	// Set up title bar spinner
	[self->tbAccSpinner startAnimation:self];
	self->_tbAcc = [[NSTitlebarAccessoryViewController alloc] init];
	[self->_tbAcc setView:self->tbAccView];
	[self->_tbAcc setLayoutAttribute:NSLayoutAttributeRight];
	[[self window] addTitlebarAccessoryViewController:self->_tbAcc];
	
	// Start observing state
	[self->_state addObserver:self
				   forKeyPath:@"isRunning"
					  options:0
					  context:NULL];
	
	// Start the "status update" timer, which will notify us when emulation
	// begins
	[[NSRunLoop currentRunLoop] addTimer:self->_statusTimer
								 forMode:NSDefaultRunLoopMode];
}

- (void) dealloc
{
	[self->_state removeObserver:self
					  forKeyPath:@"isRunning"];
}

#pragma mark - NSWindowDelegate

- (void) windowDidBecomeKey:(NSNotification *) notification
{
	[[self->wrapper remoteObjectProxy] startTrackingInputWithMap:self->_inputMap];
	
	if (self->_pausedOnUnfocus) {
		[[self->wrapper remoteObjectProxy] setPaused:NO
										 withHandler:^(FXEmulationState *current) {
											 [self->_state updateUsingState:current];
										 }];
	}
}

- (void) windowDidResignKey:(NSNotification *) notification
{
	[[self->wrapper remoteObjectProxy] stopTrackingInput];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"pauseOnUnfocus"]) {
		[[self->wrapper remoteObjectProxy] setPaused:YES
										 withHandler:^(FXEmulationState *current) {
											 [self->_state updateUsingState:current];
											 if ([current isPaused]) {
												 self->_pausedOnUnfocus = YES;
											 }
										 }];
	}
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
	[self->_statusTimer invalidate];
	
	[self->wrapper terminate];
	[[FXAppDelegate sharedInstance] cleanupWindow:self->_archive];
}

- (BOOL) windowShouldClose:(id) sender
{
	if ([self->wrapper isRunning]) {
		[[self->wrapper remoteObjectProxy] shutDown];
		return NO;
	}
	
	return YES;
}

#pragma mark - FXEmulatorEventDelegate

- (void) connectionDidEstablish:(FXEmulatorProcessWrapper *) aWrapper
{
	if ([[self window] isKeyWindow]) {
		[[aWrapper remoteObjectProxy] startTrackingInputWithMap:self->_inputMap];
	}
}

- (void) taskDidTerminate:(FXEmulatorProcessWrapper *) wrapper
{
	[[self window] close];
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
	[[self->wrapper remoteObjectProxy] setPaused:![self->_state isPaused]
									 withHandler:^(FXEmulationState *current) {
										 [self->_state updateUsingState:current];
									 }];
}

- (void) resetEmulation:(id) sender
{
	[[self->wrapper remoteObjectProxy] resetEmulationWithHandler:^(FXEmulationState *current) {
		[self->_state updateUsingState:current];
	}];
}

- (void) toggleTestMode:(id) sender
{
	[[self->wrapper remoteObjectProxy] enterDiagnostics];
}

- (void) statusUpdate:(id) sender
{
	[[self->wrapper remoteObjectProxy] updateStateWithHandler:^(FXEmulationState *current) {
		[self->_state updateUsingState:current];
		if ([self->_state isRunning]) {
			// Stop the timer
			[self->_statusTimer invalidate];
			// Initialize the graphics rendering
			[self setupIOSurface];
		}
	}];
}

#pragma mark - NSUserInterfaceValidation

- (void) setupIOSurface
{
	[[self->wrapper remoteObjectProxy] describeScreenWithHandler:^(NSInteger ioSurfaceId) {
		[self->screen setUpIOSurface:(IOSurfaceID) ioSurfaceId];
		NSLog(@"GameController: surface initialized");
	}];
}

- (BOOL) validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>) item
{
	NSMenuItem *menuItem = (NSMenuItem*) item;
	
	if ([item action] == @selector(pauseGameplay:))
	{
		if (![self->_state isPaused]) {
			[menuItem setTitle:NSLocalizedString(@"Pause", @"Gameplay")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Resume", @"Gameplay")];
		}
		
		return YES;
	}
	
	return [menuItem isEnabled];
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *) keyPath
					   ofObject:(id) object
						 change:(NSDictionary *) change
						context:(void *) context
{
	if (object == self->_state) {
		if ([keyPath isEqualToString:@"isRunning"] && [self->_state isRunning]) {
			// Emulation started, so remove the spinner
			dispatch_async(dispatch_get_main_queue(), ^{
				[self->_tbAcc removeFromParentViewController];
				self->_tbAcc = nil;
			});
		}
	}
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
	
	if (preferredSizeString) {
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

@end
