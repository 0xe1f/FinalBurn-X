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
#import "FXAppDelegate.h"

#import "FXManifest.h"

@interface FXAppDelegate ()

- (void)shutDown;

@end

@implementation FXAppDelegate
{
	FXEmulatorController *emulator;
	FXLauncherController *launcher;
	FXPreferencesController *prefs;
	NSString *appSupportPath;
	NSString *romPath;
}

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
    self->_inputMapPath = [self->appSupportPath stringByAppendingPathComponent:@"input"];
    
    NSArray *pathsToCreate = @[self->appSupportPath,
                               self->romPath,
                               self->_nvramPath,
                               self->_inputMapPath];
    
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
    [self shutDown];
    
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

- (void)launch:(NSString *) name
{
	FXDriver *driver = [[FXManifest sharedInstance] driverNamed:name];
	if (!driver) {
		return;
	}

	[self shutDown];
    @synchronized(self) {
		self->emulator = [[FXEmulatorController alloc] initWithDriver:driver];
        [self->emulator restoreSettings];
        
        [self->emulator showWindow:self];
    }
}

+ (FXAppDelegate *)sharedInstance
{
    return sharedInstance;
}

#pragma mark - Private methods

- (void)shutDown
{
    @synchronized(self) {
        [self->emulator saveSettings];
        [self->emulator close];
    }
}

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
