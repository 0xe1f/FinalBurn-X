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

@interface FXLauncherController ()

- (NSString *)auditCachePath;
- (void)identifyROMSets;
- (void)updateAudits:(NSDictionary *)audits;
- (void)importAsync:(NSArray *)paths;
//- (void)auditAsync;

@end

@implementation FXLauncherController
{
	NSOperationQueue *_importOpQueue;
	BOOL _rescanROMsAtStartup;
	NSDictionary *_setManifest;
}

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Launcher"])) {
        self->_importOpQueue = [[NSOperationQueue alloc] init];
        [self->_importOpQueue setMaxConcurrentOperationCount:1];
		
        [self setDrivers:[NSMutableArray array]];
    }
    
    return self;
}

- (void)awakeFromNib
{
	// Read the set manifest
	NSString *bundleResourcePath = [[NSBundle mainBundle] pathForResource:@"SetManifest"
																   ofType:@"plist"];
	self->_setManifest = [NSDictionary dictionaryWithContentsOfFile:bundleResourcePath];
	
    [self identifyROMSets];
	self->_rescanROMsAtStartup = NO;
	
    NSDictionary *audits;
    
    // Load the audit data from cache, if available
    NSString *auditCachePath = [self auditCachePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:auditCachePath isDirectory:nil]) {
        if ((audits = [NSKeyedUnarchiver unarchiveObjectWithFile:auditCachePath]) == nil) {
            NSLog(@"Error reading audit cache");
        }
    }
    
    if (audits == nil) {
        // Nothing in cache, or error loading. Rescan whenever possible
        self->_rescanROMsAtStartup = YES;
    }
    
    // Update ROM sets with audit data
    [self updateAudits:audits];
    
    [self->driversTreeController rearrangeObjects];
    
    [self->importProgressBar startAnimation:self];
    [self->importProgressBar setMaxValue:0];
    [self->importProgressBar setDoubleValue:0];
    
    // Observe the import queue to be notified when tasks are available/done
    [self->_importOpQueue addObserver:self
						   forKeyPath:@"operationCount"
							  options:NSKeyValueObservingOptionNew
							  context:NULL];
}

#pragma mark - NSWindowDelegate

- (void)windowDidLoad
{
    if (self->_rescanROMsAtStartup) {
		// FIXME
//        [self auditAsync];
        self->_rescanROMsAtStartup = NO;
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self->_importOpQueue cancelAllOperations];
    [self->_importOpQueue waitUntilAllOperationsAreFinished];
}

#pragma mark - FXScannerDelegate

- (BOOL) isFileSupported:(NSString *) path
{
//    // Make sure it's a ZIP file
//    if ([[path pathExtension] caseInsensitiveCompare:@"zip"] != NSOrderedSame) {
//        return NO;
//    }
//    
//    // Disallow importing from the library directory
//    NSString *parentPath = [path stringByDeletingLastPathComponent];
//    NSString *romPath = [[[FXAppDelegate sharedInstance] romRootURL] path];
//    
//    if ([parentPath caseInsensitiveCompare:romPath] == NSOrderedSame) {
//        return NO;
//    }
//    
//    NSString *archive = [[path lastPathComponent] stringByDeletingPathExtension];
//    
//    // FIXME
//    if ([archive isEqualToString:@"neogeo"]) {
//        return YES;
//    }
//    
//    // Make sure it's one of the supported ROM sets
//    __block BOOL supported = NO;
//    [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
//        if ([[romSet archive] caseInsensitiveCompare:archive] == NSOrderedSame) {
//            supported = YES;
//            *stop = YES;
//        }
//    }];
//    
//    return supported;
	return NO;
}

- (void) filesDidDrop:(NSArray *)paths
{
    [self importAsync:paths];
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *) keyPath
					   ofObject:(id) object
						 change:(NSDictionary *) change
						context:(void *) context
{
    if (object == self->_importOpQueue && [keyPath isEqualToString:@"operationCount"]) {
        NSInteger newCount = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
        
        void(^block)(void) = ^{
            if (newCount == 0) {
                // Reset panel's properties
                [self->importProgressBar setMaxValue:0];
                [self->importProgressBar setDoubleValue:0];
                
                // Hide the panel
                [NSApp endSheet:self->importProgressPanel];
            } else if (![self->importProgressPanel isVisible]) {
                // Show the import progress panel
                [NSApp beginSheet:self->importProgressPanel
                   modalForWindow:[self window]
                    modalDelegate:self
                   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
                      contextInfo:nil];
            }
        };
        
        // TODO
        if (dispatch_get_current_queue() == dispatch_get_main_queue())
        {
            block();
        }
        else
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:block];
        }
    }
}

#pragma mark - Actions

- (void) launchGame:(id)sender
{
//    FXROMSet *romSet = [[self->driversTreeController selectedObjects] lastObject];
//	FXAppDelegate *app = [FXAppDelegate sharedInstance];
//	[app launch:[romSet archive]];
}

- (void) cancelImport:(id)sender
{
    [self->importCancelButton setEnabled:NO];
    [self->importProgressLabel setStringValue:NSLocalizedString(@"Cancelling...", @"")];
    [self->_importOpQueue cancelAllOperations];
}

- (void) rescanROMs:(id) sender
{
	// FIXME
	NSLog(@"FIXME");
//    [self auditAsync];
}

#pragma mark - Callbacks

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

#pragma mark - Private methods

- (void) importAsync:(NSArray *) paths
{
	// FIXME
	NSLog(@"FIXME");
//    double maxValue = [self->importProgressBar maxValue] + [paths count];
//    [self->importProgressBar setMaxValue:maxValue];
//    
//    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
//        NSOperation *importOp = [NSBlockOperation blockOperationWithBlock:^{
//            NSString *filename = [path lastPathComponent];
//            NSString *label = [NSString stringWithFormat:NSLocalizedString(@"Importing %@...", @""),
//                               [filename stringByDeletingPathExtension]];
//            
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                // Update the label
//                [self->importProgressLabel setStringValue:label];
//                // Enable the cancel button
//                [self->importCancelButton setEnabled:YES];
//            }];
//            
//            NSURL *dstPath = [[[FXAppDelegate sharedInstance] romRootURL] URLByAppendingPathComponent:filename];
//            NSLog(@"Importing %@ as %@", filename, dstPath);
//            
//            // FIXME
//            NSError *error = nil;
//            [[NSFileManager defaultManager] copyItemAtPath:path
//                                                    toPath:[dstPath path]
//                                                     error:&error];
//            
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                // Update the progress bar
//                [self->importProgressBar incrementBy:1.0];
//            }];
//        }];
//        
//        [self->_importOpQueue addOperation:importOp];
//    }];
//    
//    if ([paths count] > 0) {
//        [self auditAsync];
//    }
}

//- (void)auditAsync
//{
//    [self->importProgressBar setMaxValue:[self->importProgressBar maxValue] + 1];
//    
//    NSBlockOperation* auditOp = [[NSBlockOperation alloc] init];
//    
//    // Make a weak reference to avoid a retain cycle
//    // http://stackoverflow.com/questions/8113268/how-to-cancel-nsblockoperation
//    __weak NSBlockOperation* weakOp = auditOp;
//    
//    [auditOp addExecutionBlock:^{
//#ifdef DEBUG
//        NSDate *started = [NSDate date];
//        NSLog(@"Auditing sets...");
//#endif
//        
//        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//            // Update the label
//            [self->importProgressLabel setStringValue:NSLocalizedString(@"Scanning...", @"")];
//            // Enable the cancel button
//            [self->importCancelButton setEnabled:YES];
//        }];
//        
//        NSMutableDictionary *audits = [NSMutableDictionary dictionary];
//		
//        // Determine the increment amount (not including subsets)
//        double incrementAmount = 1.0 / [[self drivers] count];
//        
//        // Begin the audit
//        [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
//            NSError *parentError = nil;
//            FXDriverAudit *parentDriverAudit = [loader auditSet:romSet
//                                                          error:&parentError];
//            
//            if (parentError == nil) {
//                [audits setObject:parentDriverAudit forKey:[romSet archive]];
//            } else {
//                NSLog(@"Error scanning archive %@: %@",
//                      [romSet archive], [parentError description]);
//            }
//            
//            if ([weakOp isCancelled]) {
//                *stop = YES;
//                return;
//            }
//            
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                // Update the label
//                [self->importProgressBar incrementBy:incrementAmount];
//            }];
//            
//            [[romSet subsets] enumerateObjectsUsingBlock:^(FXROMSet *subset, NSUInteger idx, BOOL *stop) {
//                if ([weakOp isCancelled]) {
//                    *stop = YES;
//                    return;
//                }
//                
//                // Go through the children as well
//                NSError *childError = NULL;
//                FXDriverAudit *childDriverAudit = [loader auditSet:subset
//                                                             error:&childError];
//                
//                if (childError == nil) {
//                    [audits setObject:childDriverAudit forKey:[subset archive]];
//                } else {
//                    NSLog(@"Error scanning archive %@: %@",
//                          [subset archive], [childError description]);
//                }
//            }];
//        }];
//        
//        if ([weakOp isCancelled]) {
//            return;
//        }
//        
//        // Save the audit data to cache file
//        NSString *auditCachePath = [self auditCachePath];
//#ifdef DEBUG
//        NSLog(@"Writing audit data to %@", auditCachePath);
//#endif
//        if (![NSKeyedArchiver archiveRootObject:audits
//                                         toFile:auditCachePath]) {
//            NSLog(@"Error writing to audit cache");
//        }
//        
//        // Update audits
//        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//            [self updateAudits:audits];
//        }];
//#ifdef DEBUG
//        NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
//#endif
//    }];
//    
//    [self->_importOpQueue addOperation:auditOp];
//}

- (NSString *) auditCachePath
{
//    FXAppDelegate *app = [FXAppDelegate sharedInstance];
//    return [[[app supportRootURL] URLByAppendingPathComponent:@"audits.cache"] path];
	return nil;
}

- (void) identifyROMSets
{
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"Identifying sets...");
#endif
    
//	[self->_setManifest enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *values, BOOL * _Nonnull stop) {
//		FXROMSet *romSet = [self FIXMEsetFromArchive:archive
//										  dictionary:values];
//		[[values objectForKey:@"subsets"] enumerateKeysAndObjectsUsingBlock:^(NSString *subarchive, NSDictionary *subvalues, BOOL * _Nonnull stop) {
//			FXROMSet *subset = [self FIXMEsetFromArchive:subarchive
//											  dictionary:subvalues];
//			[subset setParentSet:romSet];
//			[[romSet subsets] addObject:subset];
//		}];
//		
//		[[self drivers] addObject:romSet];
//	}];
	
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

- (void)updateAudits:(NSDictionary *)audits
{
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"Updating audit data...");
#endif
    
//    [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
//        FXDriverAudit *audit = [audits objectForKey:[romSet archive]];
//        [romSet setAudit:audit];
//        
//        [[romSet subsets] enumerateObjectsUsingBlock:^(FXROMSet *subset, NSUInteger idx, BOOL *stop) {
//            FXDriverAudit *subAudit = [audits objectForKey:[subset archive]];
//            [subset setAudit:subAudit];
//        }];
//    }];
	
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

@end
