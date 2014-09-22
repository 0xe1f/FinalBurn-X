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

#import "FXROMSet.h"

@implementation FXAppDelegate

static FXAppDelegate *sharedInstance = nil;

+ (void)initialize
{
    // Register the NSUserDefaults
    NSString *bundleResourcePath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:bundleResourcePath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

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
    // Initialize paths
    self->appSupportPath = [[self appSupportURL] path];
    self->romPath = [self->appSupportPath stringByAppendingPathComponent:@"roms"];
    self->_nvramPath = [self->appSupportPath stringByAppendingPathComponent:@"nvram"];
    
    NSArray *pathsToCreate = @[self->appSupportPath,
                               self->romPath,
                               self->_nvramPath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [pathsToCreate enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSError *error = NULL;
        if (![fm fileExistsAtPath:path]) {
            [fm createDirectoryAtPath:path
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            
            if (error != nil) {
                NSLog(@"Error initializing path '%@': %@",
                      path, [error description]);
            }
        }
    }];
    
    // One-time initialization of the emulation core
    [FXEmulatorController initializeCore];
    
    // Initialize the launcher
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

#pragma mark - Actions

- (void)showLauncher:(id)sender
{
    [[self->launcher window] makeKeyAndOrderFront:self];
}

- (void)showPreferences:(id)sender
{
    if (self->prefs == nil) {
        self->prefs = [[FXPreferencesController alloc] init];
        [self->prefs showWindow:self];
    } else {
        [[self->prefs window] makeKeyAndOrderFront:self];
    }
}

#pragma mark - Public methods

- (NSString *)ROMPath
{
    return self->romPath;
}

- (FXEmulatorController *)emulator
{
    return self->emulator;
}

- (FXPreferencesController *)prefs
{
    return self->prefs;
}

- (void)launch:(FXROMSet *)romSet
{
    @synchronized(self) {
        [self->emulator close];
        
        self->emulator = [[FXEmulatorController alloc] initWithROMSet:romSet];
        [self->emulator showWindow:self];
    }
}

+ (FXAppDelegate *)sharedInstance
{
    return sharedInstance;
}

#pragma mark - Private methods

- (NSURL *)appSupportURL
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL *appSupportUrl = [[fm URLsForDirectory:NSApplicationSupportDirectory
                                       inDomains:NSUserDomainMask] lastObject];
    
    if (appSupportUrl == nil) {
        return nil;
    }
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *appName = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
    
    return [appSupportUrl URLByAppendingPathComponent:appName];
}

@end
