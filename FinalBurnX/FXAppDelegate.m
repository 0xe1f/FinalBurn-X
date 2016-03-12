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
#import "FXAppDelegate.h"

#import <OpenEmuXPCCommunicator/OpenEmuXPCCommunicator.h>

#import "FXPreferencesController.h"
#import "FXLauncherController.h"
#import "FXGameController.h"

NSString *const kFXNotificationCache = @"cache";
NSString *const FXNotificationCacheChanged = @"org.akop.finalburnx.CacheChange";

@implementation FXAppDelegate
{
	FXLauncherController *_launcher;
	FXPreferencesController *_prefs;
	
	NSMutableDictionary *_emulatorWindows;
}

static FXAppDelegate *sharedInstance = nil;

+ (void) initialize
{
    // Register the NSUserDefaults
    NSString *bundleResourcePath = [[NSBundle mainBundle] pathForResource:@"Defaults"
																   ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:bundleResourcePath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (instancetype) init
{
    if (self = [super init]) {
        sharedInstance = self;
		
		self->_emulatorWindows = [NSMutableDictionary dictionary];
		self->_setManifest = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - NSAppDelegate

- (void) applicationWillFinishLaunching:(NSNotification *) notification
{
    // Initialize paths
	NSFileManager* fm = [NSFileManager defaultManager];
	NSURL *supportRootURL = [[fm URLsForDirectory:NSApplicationSupportDirectory
										inDomains:NSUserDomainMask] lastObject];
	
	NSAssert(supportRootURL != nil, @"App support URL is null!");
	
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NSString *appName = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
	
	self->_supportRootURL = [supportRootURL URLByAppendingPathComponent:appName];
	
    self->_romRootURL = [self->_supportRootURL URLByAppendingPathComponent:@"roms"];
	self->_inputMapRootURL = [self->_supportRootURL URLByAppendingPathComponent:@"input"];
	self->_auditCachePath = [[self->_supportRootURL URLByAppendingPathComponent:@"audit.cache"] path];
	NSURL *nvramRootURL = [self->_supportRootURL URLByAppendingPathComponent:@"nvram"];
	
    NSArray *pathsToCreate = @[ self->_supportRootURL,
								self->_romRootURL,
								nvramRootURL,
								self->_inputMapRootURL];
    
    [pathsToCreate enumerateObjectsUsingBlock:^(NSURL *root, NSUInteger idx, BOOL *stop) {
        NSError *error = NULL;
		NSString *path = [root path];
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
	
	// Load set manifest
	NSString *bundleResourcePath = [[NSBundle mainBundle] pathForResource:@"SetManifest"
																   ofType:@"plist"];
	self->_setManifest = [NSDictionary dictionaryWithContentsOfFile:bundleResourcePath];
	
	[self->_scanner setRootPath:[self->_romRootURL path]];
	[self->_scanner setSets:self->_setManifest];
}

- (void) applicationDidFinishLaunching:(NSNotification *) aNotification
{
	[OEXPCCAgentConfiguration defaultConfiguration];
	[OEXPCCAgent defaultAgent];
	
	[self showLauncher:nil];
}

- (void) applicationWillTerminate:(NSNotification *) notification
{
	[[OEXPCCAgentConfiguration defaultConfiguration] tearDownAgent];
	[self->_scanner stopAll];
}

#pragma mark - FXScannerDelegate

- (void) scanDidComplete:(NSDictionary *) result
{
	BOOL wroteCache = [result writeToFile:self->_auditCachePath
							   atomically:YES];
	if (wroteCache) {
		[[NSNotificationCenter defaultCenter] postNotificationName:FXNotificationCacheChanged
															object:self
														  userInfo:@{ kFXNotificationCache: result }];
	}
}

- (void) scanDidFail:(NSError *) error
{
	NSLog(@"FIXME: %@", [error description]);
}

#pragma mark - Actions

- (void) showLauncher:(id) sender
{
	@synchronized(self->_emulatorWindows) {
		if (self->_launcher == nil) {
			self->_launcher = [[FXLauncherController alloc] init];
		}
	}
	
	[self->_launcher showWindow:self];
}

- (void)showPreferences:(id) sender
{
	@synchronized(self->_emulatorWindows) {
		if (self->_prefs == nil) {
			self->_prefs = [[FXPreferencesController alloc] init];
		}
	}
	
	[self->_prefs showWindow:self];
}

#pragma mark - Public methods

- (void) launch:(NSString *) archive
{
	if ([self->_setManifest objectForKey:archive] == nil) {
		return;
	}
	
	FXGameController *e = nil;
	@synchronized(self->_emulatorWindows) {
		e = [self->_emulatorWindows objectForKey:archive];
		if (e == nil) {
			e = [[FXGameController alloc] initWithArchive:archive];
			[self->_emulatorWindows setObject:e
									   forKey:archive];
		}
	}
	
	[e showWindow:self];
}

- (void) cleanupWindow:(NSString *) archive
{
	@synchronized(self->_emulatorWindows) {
		[self->_emulatorWindows removeObjectForKey:archive];
	}
}

+ (FXAppDelegate *) sharedInstance
{
    return sharedInstance;
}

@end
