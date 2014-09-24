/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014 Akop Karapetyan
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

@end

@implementation FXEmulatorController

- (instancetype)initWithROMSet:(FXROMSet *)romSet
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setInput:[[FXInput alloc] initWithROMSet:romSet]];
        [self setVideo:[[FXVideo alloc] init]];
        [self setAudio:[[FXAudio alloc] init]];
        [self setRunLoop:[[FXRunLoop alloc] initWithROMSet:romSet]];
        
        [self setRomSet:romSet];
    }
    
    return self;
}

- (void)awakeFromNib
{
    NSString *title = [[self romSet] title];
    NSSize screenSize = [[self romSet] screenSize];
    NSSize preferredSize = [self preferredSizeOfScreenWithSize:screenSize];
    
    [[self input] restoreInputMap];
    
    [[self window] setTitle:title];
    [[self window] setContentSize:preferredSize];
    
    [[self video] setDelegate:self->screen];
    [[self runLoop] setDelegate:self];
    
    [[self runLoop] start];
}

#pragma mark - FXRunLoopDelegate

- (void)loadingDidStart
{
    [self->spinner startAnimation:self];
    
    // Block the window from being closed (until loading completes)
    NSUInteger windowStyleMask = [[self window] styleMask];
    [[self window] setStyleMask:(windowStyleMask &~ NSClosableWindowMask)];
}

- (void)loadingDidEnd
{
    [self->spinner stopAnimation:self];
    
    // Make window closable again
    NSUInteger windowStyleMask = [[self window] styleMask];
    [[self window] setStyleMask:(windowStyleMask | NSClosableWindowMask)];
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
    [[self video] setDelegate:nil];
    [[self input] saveInputMap];
    
    [[self runLoop] cancel];
}

- (NSSize)windowWillResize:(NSWindow *)sender
                    toSize:(NSSize)frameSize
{
    NSSize screenSize = [[self romSet] screenSize];
    if (screenSize.width == 0 || screenSize.height == 0) {
        // Screen size is not yet available
    } else {
        NSRect windowFrame = [[self window] frame];
        NSRect viewRect = [self->screen convertRect:[self->screen bounds]
                                             toView: nil];
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

#pragma mark - Private methods

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
    NSSize glViewSize = [self->screen frame].size;
    
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

@end
