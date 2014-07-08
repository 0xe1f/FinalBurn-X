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

#import "FXInput.h"
#import "FXVideo.h"
#import "FXAudio.h"
#import "FXRunLoop.h"
#import "FXLoader.h"

#include "burner.h"

@interface FXEmulatorController ()

- (void)windowKeyDidChange:(BOOL)isKey;
- (void)resizeFrame:(NSSize)newSize
            animate:(BOOL)animate;

@end

@implementation FXEmulatorController

- (instancetype)initWithDriverId:(int)driverId
{
    if ((self = [super initWithWindowNibName:@"Emulator"])) {
        [self setInput:[[FXInput alloc] init]];
        [self setVideo:[[FXVideo alloc] init]];
        [self setAudio:[[FXAudio alloc] init]];
        [self setRunLoop:[[FXRunLoop alloc] initWithDriverId:driverId]];
        
        [self setDriverId:driverId];
    }
    
    return self;
}

- (void)awakeFromNib
{
    NSString *title = [[FXLoader sharedLoader] titleForDriverId:[self driverId]];
    [[self window] setTitle:title];
    
    [[self video] setDelegate:self->screen];
    [[self runLoop] start];
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
    [[self runLoop] cancel];
}

- (NSSize)windowWillResize:(NSWindow *)sender
                    toSize:(NSSize)frameSize
{
    NSSize screenSize = [self->screen screenSize];
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
    NSSize screenSize = [self->screen screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        NSRect windowFrame = [[self window] frame];
        NSRect contentRect = [[self window] contentRectForFrameRect:windowFrame];
        
        NSLog(@"Screen resized. Actual: (%.00f,%.00f); Virtual: (%.00f,%.00f)",
              screenSize.width, screenSize.height,
              contentRect.size.width, contentRect.size.height);
    }
}

#pragma mark - FXScreenViewDelegate

- (void)screenSizeDidChange:(NSSize)newSize
{
#ifdef DEBUG
    NSLog(@"screenSizeDidChange (%.02f,%.02f)", newSize.width, newSize.height);
#endif
    
    [[self window] setContentSize:newSize];
}

#pragma mark - Actions

- (void)resizeNormalSize:(id)sender
{
    NSSize screenSize = [self->screen screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        [self resizeFrame:screenSize
                  animate:YES];
    }
}

- (void)resizeDoubleSize:(id)sender
{
    NSSize screenSize = [self->screen screenSize];
    if (screenSize.width != 0 && screenSize.height != 0) {
        NSSize doubleSize = NSMakeSize(screenSize.width * 2, screenSize.height * 2);
        [self resizeFrame:doubleSize
                  animate:YES];
    }
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

@end
