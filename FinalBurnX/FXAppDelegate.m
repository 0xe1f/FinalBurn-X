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
#import "FXAppDelegate.h"

#import <IOKit/pwr_mgt/IOPMLib.h>

#import "FXAboutController.h"

#import "FXManifest.h"
#import "AKGamepadManager.h"

@interface FXAppDelegate ()

- (void)shutDown;

@end

@implementation FXAppDelegate
{
	FXLauncherController *launcher;
	NSString *appSupportPath;
	IOPMAssertionID _preventSleepAssertionID;
    FXAboutController *_aboutController;
}

static FXAppDelegate *sharedInstance = nil;

+ (void) initialize
{
    // Register the NSUserDefaults
    NSString *bundleResourcePath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:bundleResourcePath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (instancetype) init
{
	if (self = [super init]) {
		sharedInstance = self;
	}
	
	return self;
}

- (void) dealloc
{
}

- (void) awakeFromNib
{
	_preventSleepAssertionID = kIOPMNullAssertionID;
}

#pragma mark - NSAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// Initialize GM; will kick off gamepads enumeration, etc
	[AKGamepadManager sharedInstance];

	// Initialize paths
    self->appSupportPath = [[self appSupportURL] path];
    _romPath = [self->appSupportPath stringByAppendingPathComponent:@"roms"];
    _nvramPath = [self->appSupportPath stringByAppendingPathComponent:@"nvram"];
    _inputMapPath = [self->appSupportPath stringByAppendingPathComponent:@"input"];
	_dipPath = [self->appSupportPath stringByAppendingPathComponent:@"dip"];
    
    NSArray *pathsToCreate = @[self->appSupportPath,
                               _romPath,
                               _nvramPath,
                               _inputMapPath,
							   _dipPath];
    
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

- (void) showLauncher:(id)sender
{
    [[self->launcher window] makeKeyAndOrderFront:self];
}

- (void) showPreferences:(id)sender
{
    if (!_prefs) {
        _prefs = [FXPreferencesController new];
        [_prefs showWindow:self];
    } else {
        [[_prefs window] makeKeyAndOrderFront:self];
    }
}

- (void) showAbout:(id) sender
{
    if (!_aboutController) {
        _aboutController = [FXAboutController new];
        [_aboutController showWindow:self];
    } else {
        [[_aboutController window] makeKeyAndOrderFront:self];
    }
}

#pragma mark - Public methods

- (void) suppressScreenSaver
{
	if (_preventSleepAssertionID != kIOPMNullAssertionID) {
		return;
	}

	IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
								kIOPMAssertionLevelOn,
								(__bridge CFStringRef) @"FinalBurnX",
								&_preventSleepAssertionID);

#if DEBUG
	NSLog(@"app/suppressScreenSaver");
#endif
}

- (void) restoreScreenSaver
{
	if (_preventSleepAssertionID == kIOPMNullAssertionID) {
		return;
	}

	_preventSleepAssertionID = kIOPMNullAssertionID;
	IOPMAssertionRelease(_preventSleepAssertionID);

#if DEBUG
	NSLog(@"app/restoreScreenSaver");
#endif
}

- (void)launch:(NSString *) name
{
	FXDriver *driver = [[FXManifest sharedInstance] driverNamed:name];
	if (!driver) {
		return;
	}

	[self shutDown];
    @synchronized(self) {
		_emulator = [[FXEmulatorController alloc] initWithDriver:driver];
        [_emulator restoreSettings];
        
        [_emulator showWindow:self];
    }
}

+ (FXAppDelegate *)sharedInstance
{
    return sharedInstance;
}

#pragma mark - Private methods

- (void) shutDown
{
    @synchronized(self) {
        [_emulator saveSettings];
        [_emulator close];
		_emulator = nil;
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

    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    return [appSupportUrl URLByAppendingPathComponent:[infoDict objectForKey:@"CFBundleName"]];
}

@end
