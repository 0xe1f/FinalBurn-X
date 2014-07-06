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
#import "FXAppDelegate.h"

@implementation FXAppDelegate

static FXAppDelegate *sharedInstance = nil;

- (instancetype)init
{
    if (self = [super init]) {
        sharedInstance = self;
    }
    
    return self;
}

- (void)dealloc
{
}

#pragma mark - NSAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [FXEmulatorController initializeCore];
    
    self->launcher = [[FXLauncherController alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self->launcher showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [FXEmulatorController cleanupCore];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

#pragma mark - Etc

- (FXEmulatorController *)emulator
{
    return self->emulator;
}

- (void)launch:(int)driverId
{
    @synchronized(self) {
        [self->emulator close];
        
        self->emulator = [[FXEmulatorController alloc] initWithDriverId:driverId];
        [self->emulator showWindow:self];
    }
}

+ (FXAppDelegate *)sharedInstance
{
    return sharedInstance;
}

@end
