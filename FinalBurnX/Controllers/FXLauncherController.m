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
#import "FXLauncherController.h"

#import "FXGameController.h"
#import "FXAppDelegate.h"

#import "FXScanner.h"
#import "FXImporter.h"

@interface FXLauncherController ()

- (void) auditCacheDidChange:(NSNotification *) notification;

- (void) readSetManifest;
- (void) resetAuditCache:(NSDictionary *) cache;

@end

@implementation FXLauncherController
{
	NSMutableDictionary<NSString *, NSMutableDictionary *> *_setMap;
}

- (id) init
{
    if ((self = [super initWithWindowNibName:@"Launcher"])) {
		self->sets = [NSMutableArray array];
		self->_setMap = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:FXNotificationCacheChanged
												  object:nil];
}

- (void) awakeFromNib
{
	FXAppDelegate *app = [FXAppDelegate sharedInstance];
	
#if DEBUG
	NSDate *started = [NSDate date];
#endif
	[self readSetManifest];
	
	NSDictionary *cache = [NSDictionary dictionaryWithContentsOfFile:[app auditCachePath]];
	if (cache) {
		[self resetAuditCache:cache];
	}
#ifdef DEBUG
	NSLog(@"Completed set init (%.04fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
	
    [self->setTreeController rearrangeObjects];
    
    [self->importProgressBar startAnimation:self];
    [self->importProgressBar setMaxValue:0];
    [self->importProgressBar setDoubleValue:0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(auditCacheDidChange:)
												 name:FXNotificationCacheChanged
											   object:nil];
}

#pragma mark - NSWindowDelegate

- (void) windowWillLoad
{
}

#pragma mark - FXDropDelegate

- (BOOL) isFileSupported:(NSString *) path
{
	FXAppDelegate *app = [FXAppDelegate sharedInstance];
	
    // Disallow importing from the library directory
    NSString *romPath = [[app romRootURL] path];
	// FIXME: what if the FS is case-sensitive?
    if ([[path stringByDeletingLastPathComponent] caseInsensitiveCompare:romPath] == NSOrderedSame) {
        return NO;
    }
	
	// See if the importer can handle it
	return [FXImporter canImportPath:path
						 setManifest:[app setManifest]];
}

- (void) filesDidDrop:(NSArray *) paths
{
	FXImporter *importer = [[FXImporter alloc] init];
	
	[importer setSetManifest:[[FXAppDelegate sharedInstance] setManifest]];
	[importer setSetPath:[[[FXAppDelegate sharedInstance] romRootURL] path]];
	[importer setImportPaths:paths];
	
	// FIXME
	[[NSOperationQueue mainQueue] addOperation:importer];
}

#pragma mark - Actions

- (void) launchGame:(id) sender
{
	NSDictionary *set = [[self->setTreeController selectedObjects] lastObject];
	
	FXAppDelegate *app = [FXAppDelegate sharedInstance];
	[app launch:[set objectForKey:@"archive"]];
}

- (void) rescanROMs:(id) sender
{
	[[[FXAppDelegate sharedInstance] scanner] start];
}

#pragma mark - Callbacks

- (void) didEndSheet:(NSWindow *) sheet
		  returnCode:(NSInteger) returnCode
		 contextInfo:(void *) contextInfo
{
    [sheet orderOut:self];
}

#pragma mark - Notifications

- (void) auditCacheDidChange:(NSNotification *) notification
{
#if DEBUG
	NSDate *started = [NSDate date];
#endif
	[self resetAuditCache:[[notification userInfo] objectForKey:kFXNotificationCache]];
#ifdef DEBUG
	NSLog(@"Reset audit cache (%.04fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

#pragma mark - Private methods

- (void) readSetManifest
{
	@synchronized(self->sets) {
		[self->sets removeAllObjects];
		[self->_setMap removeAllObjects];
		
		// Initialize set map
		FXAppDelegate *app = [FXAppDelegate sharedInstance];
		[[app setManifest] enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *values, BOOL * _Nonnull stop) {
			if ([[values objectForKey:@"attrs"] containsString:@"unplayable"]) {
				// Don't list unplayable items (e.g. Neo-Geo BIOS set)
				return;
			}
			
			NSMutableDictionary *set = [ @{ @"archive": archive,
											@"title": [values objectForKey:@"title"],
											@"status": @(FXSetStatusIncomplete),
											@"system": [values objectForKey:@"system"],
											@"subsets": [NSMutableArray array] } mutableCopy];
			
			[self->_setMap setObject:set
							  forKey:archive];
		}];
		
		// Initialize set list
		[self->_setMap enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSMutableDictionary *set, BOOL * _Nonnull stop) {
			NSString *parent = [[[app setManifest] objectForKey:archive] objectForKey:@"parent"];
			NSMutableArray *root;
			if (parent) {
				root = [[self->_setMap objectForKey:parent] objectForKey:@"subsets"];
			} else {
				root = self->sets;
			}
			
			[root addObject:set];
		}];
	}
}

- (void) resetAuditCache:(NSDictionary *) cache
{
	NSMutableSet<NSString *> *unprocessed = [NSMutableSet setWithArray:[self->_setMap allKeys]];
	// Process all sets in cache
	[cache enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *values, BOOL * _Nonnull stop) {
		NSMutableDictionary *set = [self->_setMap objectForKey:archive];
		[set setObject:[values objectForKey:kFXSetStatus]
				forKey:@"status"];
		[unprocessed removeObject:archive];
	}];
	
	// Invalidate the rest
	[unprocessed enumerateObjectsUsingBlock:^(NSString *archive, BOOL * _Nonnull stop) {
		NSMutableDictionary *set = [self->_setMap objectForKey:archive];
		[set setObject:@(FXSetStatusIncomplete)
				forKey:@"status"];
	}];
}

@end
