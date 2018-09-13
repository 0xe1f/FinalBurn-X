/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
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
#import "FXEmulatorController.h"

#import "FXLoader.h"
#import "FXManifest.h"
#import "FXAppDelegate.h"
#import "FXDIPState.h"

#include "burner.h"

@interface FXEmulatorController ()

- (NSSize) preferredSizeOfScreenWithSize:(NSSize) screenSize;
- (void) resizeFrame:(NSSize) newSize
			 animate:(BOOL) animate;
- (void) displayMessage:(NSString *) message;
- (NSString *) generateScreenshotFilenameAtPath:(NSString *) parentPath
									  extension:(NSString *) ext;
- (void) restoreDIPSwitches;
- (void) saveDIPSwitches;

@end

@implementation FXEmulatorController
{
	NSTitlebarAccessoryViewController *_tbAcc;

	BOOL _autoPaused;
	BOOL _cursorVisible;
	NSArray<NSString *> *_defaultsToObserve;
}

- (instancetype) initWithDriver:(FXDriver *) driver
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
		_driver = driver;
		_input = [[FXInput alloc] initWithDriver:driver];
		_video = [[FXVideo alloc] init];
		_audio = [[FXAudio alloc] init];
		_runLoop = [[FXRunLoop alloc] initWithDriver:driver];
		_cursorVisible = YES;
		_dipState = [[FXDIPState alloc] initWithDriverName:[driver name]];
		_defaultsToObserve = @[ @"audioVolume",
								@"pauseWhenInactive",
								@"suppressScreenSaver",
							   ];
	}
	
    return self;
}

- (void) awakeFromNib
{
	[_defaultsToObserve enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
		[[NSUserDefaults standardUserDefaults] addObserver:self
												forKeyPath:key
												   options:NSKeyValueObservingOptionNew
												   context:NULL];
	}];

	// Initialize title bar controller
	self->_tbAcc = [[NSTitlebarAccessoryViewController alloc] init];
	[self->_tbAcc setView:self->spinner];
	[self->_tbAcc setLayoutAttribute:NSLayoutAttributeRight];
	
	NSString *title = [_driver title];
    NSSize preferredSize = [self preferredSizeOfScreenWithSize:[_driver screenSize]];
	
    [[self window] setTitle:title];
    [[self window] setContentSize:preferredSize];
//	[[[self window] contentView] setWantsLayer:YES];
//	[[[self window] contentView] setBackgroundColor:[NSColor blackColor]];
	
    [_video setDelegate:self->screen];
    [_runLoop setDelegate:self];
    [_runLoop start];
	[_audio setVolume:[[NSUserDefaults standardUserDefaults] integerForKey:@"audioVolume"]];
	
	[screen setDelegate:self];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:FXEmulatorChanged
                                                        object:self
                                                      userInfo:nil];
}

- (void) dealloc
{
	[screen setDelegate:nil];
}

#pragma mark - Notifications

- (void)observeValueForKeyPath:(NSString *) keyPath
					  ofObject:(id) object
						change:(NSDictionary *) change
					   context:(void *) context
{
	NSWindow *window = [self window];
	if ([keyPath isEqualToString:@"audioVolume"]) {
		[_audio setVolume:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
	} else if ([keyPath isEqualToString:@"pauseWhenInactive"]) {
		BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if (![window isKeyWindow] && newValue && ![_runLoop isPaused]) {
			[_runLoop setPaused:YES];
			_autoPaused = YES;
		}
	} else if ([keyPath isEqualToString:@"suppressScreenSaver"]) {
		BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if (newValue && [window isKeyWindow]) {
			[(FXAppDelegate *) [NSApp delegate] suppressScreenSaver];
		} else if (!newValue) {
			[(FXAppDelegate *) [NSApp delegate] restoreScreenSaver];
		}
	}
}

#pragma mark - FXRunLoopDelegate

- (void)loadingDidStart
{
	dispatch_async(dispatch_get_main_queue(), ^{
//		[self->screen setHidden:YES];
		
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
//			[[[self window] contentView] setWantsLayer:NO];
		} else {
			[self displayMessage:NSLocalizedString(@"The emulator shut down unexpectedly. Game may be unsupported or unplayable.",
												   @"Error message")];
		}
	});
}

#pragma mark - NSWindowDelegate

- (void) windowDidBecomeKey:(NSNotification *) notification
{
	[_input setFocus:YES];

	if (_autoPaused && [_runLoop isPaused]) {
		[_runLoop setPaused:NO];
	}

	_autoPaused = NO;

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"suppressScreenSaver"]) {
		[(FXAppDelegate *) [NSApp delegate] suppressScreenSaver];
	}
}

- (void) windowDidResignKey:(NSNotification *) notification
{
	[_input setFocus:NO];
	if (!_cursorVisible) {
		_cursorVisible = YES;
		[NSCursor unhide];
	}

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"pauseWhenInactive"]
		&& ![_runLoop isPaused]) {
		[_runLoop setPaused:YES];
		_autoPaused = YES;
	}

	[(FXAppDelegate *) [NSApp delegate] restoreScreenSaver];
}

- (void) keyDown:(NSEvent *) theEvent
{
    // Suppress the beeps
}

- (void) windowWillClose:(NSNotification *) notification
{
	[_defaultsToObserve enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
		[[NSUserDefaults standardUserDefaults] removeObserver:self
												   forKeyPath:key];
	}];

	[[NSNotificationCenter defaultCenter] postNotificationName:FXEmulatorChanged
                                                        object:self
                                                      userInfo:nil];
    
    [_video setDelegate:nil];
    [_runLoop cancel];
	
	if (!_cursorVisible) {
		[NSCursor unhide];
	}
}

- (NSSize) windowWillResize:(NSWindow *) sender
					 toSize:(NSSize) frameSize
{
    NSSize screenSize = [_driver screenSize];
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
	
    return frameSize;
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSSize screenSize = [_driver screenSize];
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
    NSSize screenSize = [_driver screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        [self resizeFrame:screenSize
                  animate:YES];
    }
}

- (void)resizeDoubleSize:(id)sender
{
    NSSize screenSize = [_driver screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        NSSize doubleSize = NSMakeSize(screenSize.width * 2, screenSize.height * 2);
        [self resizeFrame:doubleSize
                  animate:YES];
    }
}

- (void)pauseGameplay:(id)sender
{
    [_runLoop setPaused:![_runLoop isPaused]];
}

- (void)resetEmulation:(id)sender
{
	[_input setResetPressed:YES];
}

- (void)toggleTestMode:(id)sender
{
    [_input setTestPressed:YES];
}

- (void)saveScreenshot:(id)sender
{
	NSString *path = [self generateScreenshotFilenameAtPath:nil
												  extension:@"png"];
	
	if (path) {
		MakeScreenShot([path cStringUsingEncoding:NSUTF8StringEncoding]);
	}
}

- (void)saveScreenshotAs:(id)sender
{
	[self showSaveFileDialogWithTitle:NSLocalizedString(@"Save Screenshot", @"Dialog title")
					 allowedFileTypes:@[@"png"]
					  openInDirectory:nil
					completionHandler:^(NSString *file, NSString *path) {
		 if (file) {
			 MakeScreenShot([file cStringUsingEncoding:NSUTF8StringEncoding]);
		 }
	 }];
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
	[_input save];
	[self saveDIPSwitches];
}

- (void)restoreSettings
{
    [_input restore];
	[self restoreDIPSwitches];
}

#pragma mark - Private methods

- (void) showSaveFileDialogWithTitle:(NSString *) title
					allowedFileTypes:(NSArray *) allowedFileTypes
					 openInDirectory:(NSString *) initialDirectory
				   completionHandler:(void (^)(NSString *file, NSString *path)) handler
{
	NSSavePanel *dialog = [NSSavePanel savePanel];
	
	dialog.title = title;
	dialog.canCreateDirectories = YES;
	dialog.allowedFileTypes = allowedFileTypes;
	
	if (initialDirectory)
		dialog.directoryURL = [NSURL fileURLWithPath:initialDirectory];
	
	[dialog beginSheetModalForWindow:[self->screen window]
				   completionHandler:^(NSInteger result)
	 {
		 NSString *file = nil;
		 NSString *filePath = nil;
		 
		 if (result == NSFileHandlingPanelOKButton)
		 {
			 file = [dialog URL].path;
			 filePath = dialog.directoryURL.path;
		 }
		 
		 handler(file, filePath);
	 }];
}

- (NSString *) generateScreenshotFilenameAtPath:(NSString *) parentPath
									  extension:(NSString *) ext
{
	NSString *path = nil;
	
	if (parentPath == nil) {
		// Default parent is desktop
		parentPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
	}
	
	if (parentPath != nil) {
		NSDate *now = [NSDate date];
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *components = [calendar components:NSCalendarUnitYear
										| NSCalendarUnitMonth | NSCalendarUnitDay
										| NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
												   fromDate:now];
		
		NSString *prefix = [NSString stringWithFormat:@"%@ %04zd-%02zd-%02zd at %02zd.%02zd.%02zd",
							[self->_driver title],
							[components year], [components month], [components day],
							[components hour], [components minute], [components second]];
		
		path = [parentPath stringByAppendingPathComponent:prefix];
		path = [path stringByAppendingPathExtension:ext];
		
		for (int i = 2; [[NSFileManager defaultManager] fileExistsAtPath:path]; i++) {
			path = [[parentPath stringByAppendingPathComponent:prefix] stringByAppendingFormat:@" %zd", i];
			path = [path stringByAppendingPathExtension:ext];
		}
	}
	
	return path;
}

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
    // Turn off full screen if active
    if (([[NSApplication sharedApplication] presentationOptions] & NSApplicationPresentationFullScreen) != 0) {
        [[self window] toggleFullScreen:nil];
    }

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

- (void) restoreDIPSwitches
{
	FXAppDelegate *app = [FXAppDelegate sharedInstance];
	NSString *file = [[_driver name] stringByAppendingPathExtension:@"dip"];
	NSString *path = [[app dipPath] stringByAppendingPathComponent:file];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:path isDirectory:nil]) {
		FXDIPState *state = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
		if (!state) {
			NSLog(@"Error reading DIP switch config");
			[_dipState reset];
		} else {
			_dipState = state;
		}
	}

	[_input updateDIPSwitches:_dipState];
}

- (void) saveDIPSwitches
{
	if ([_dipState dirty]) {
		FXAppDelegate *app = [FXAppDelegate sharedInstance];
		NSString *file = [[_driver name] stringByAppendingPathExtension:@"dip"];
		NSString *path = [[app dipPath] stringByAppendingPathComponent:file];
		
		if (![NSKeyedArchiver archiveRootObject:_dipState
										 toFile:path]) {
			NSLog(@"Error writing dip switch config");
		} else {
			[_dipState clearDirtyFlag];
		}
	}
}

#pragma mark - NSUserInterfaceValidation

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    NSMenuItem *menuItem = (NSMenuItem*)item;
    if ([item action] == @selector(pauseGameplay:)) {
        if (![_runLoop isPaused]) {
            [menuItem setTitle:NSLocalizedString(@"Pause", @"Gameplay")];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Resume", @"Gameplay")];
        }
        
        return YES;
    }

    return YES;
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
