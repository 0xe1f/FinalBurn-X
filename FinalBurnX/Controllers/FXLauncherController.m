/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) Akop Karapetyan
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
#import "FXLauncherController.h"

#import "FXEmulatorController.h"
#import "FXAppDelegate.h"
#import "FXLoader.h"
#import "FXManifest.h"

@interface FXLauncherController ()

- (NSString *)auditCachePath;
- (void)identifyROMSets;
- (void)updateAudits:(NSDictionary *)audits;
- (void)importAsync:(NSArray *)paths;
- (void)auditAsync;
- (BOOL) doesDriverArray:(NSArray<FXDriver *>*) driverArray
      containDriverNamed:(NSString *) driverName;

@end

@implementation FXLauncherController

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Launcher"])) {
        self->importOpQueue = [[NSOperationQueue alloc] init];
        [self->importOpQueue setMaxConcurrentOperationCount:1];
        
        [self setDrivers:[NSMutableArray array]];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [self identifyROMSets];
    
    self->rescanROMsAtStartup = NO;
    
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
        self->rescanROMsAtStartup = YES;
    }
    
    // Update ROM sets with audit data
    [self updateAudits:audits];
    
    [self->driversTreeController rearrangeObjects];
    
    [self->importProgressBar startAnimation:self];
    [self->importProgressBar setMaxValue:0];
    [self->importProgressBar setDoubleValue:0];
	
    // Observe the import queue to be notified when tasks are available/done
    [self->importOpQueue addObserver:self
                          forKeyPath:@"operationCount"
                             options:NSKeyValueObservingOptionNew
                             context:NULL];
}

#pragma mark - NSWindowDelegate

- (void)windowDidLoad
{
    if (self->rescanROMsAtStartup) {
        [self auditAsync];
        self->rescanROMsAtStartup = NO;
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self->importOpQueue cancelAllOperations];
    [self->importOpQueue waitUntilAllOperationsAreFinished];
}

#pragma mark - FXScannerDelegate

- (BOOL) isArchiveSupported:(NSString *)path
{
    // Make sure it's a ZIP file
    if ([[path pathExtension] caseInsensitiveCompare:@"zip"] != NSOrderedSame) {
        return NO;
    }
    
    // Disallow importing from the library directory
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    NSString *romPath = [[FXAppDelegate sharedInstance] romPath];
    
    if ([parentPath caseInsensitiveCompare:romPath] == NSOrderedSame) {
        return NO;
    }
    
    NSString *archive = [[path lastPathComponent] stringByDeletingPathExtension];

    return [self doesDriverArray:_drivers
              containDriverNamed:archive];
}

- (BOOL) doesDriverArray:(NSArray<FXDriver *>*) driverArray
      containDriverNamed:(NSString *) driverName
{
    if ([driverName isEqualTo:@"neogeo"]) {
        return YES;
    }

    __block BOOL supported = NO;
    [driverArray enumerateObjectsUsingBlock:^(FXDriver *driver, NSUInteger idx, BOOL *stop) {
        if ([[driver name] caseInsensitiveCompare:driverName] == NSOrderedSame) {
            supported = YES;
        } else if ([[driver children] count] > 0) {
            supported = [self doesDriverArray:[driver children]
                           containDriverNamed:driverName];
        }
        if (supported) *stop = YES;
    }];

    return supported;
}

- (void) importArchives:(NSArray *)paths
{
    [self importAsync:paths];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self->importOpQueue && [keyPath isEqualToString:@"operationCount"]) {
        NSInteger newCount = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
        
        void(^block)(void) = ^{
            if (newCount == 0) {
                // Reset panel's properties
                if ([NSThread isMainThread]) {
                    [self->importProgressBar setMaxValue:0];
                    [self->importProgressBar setDoubleValue:0];
                }

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
        
        if (![NSThread isMainThread])
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

- (void)launchGame:(id)sender
{
    FXDriver *driver = [[self->driversTreeController selectedObjects] lastObject];
    if ([[driver audit] isPlayable]) {
        FXAppDelegate *app = [FXAppDelegate sharedInstance];
        [app launch:[driver name]];
    }
}

- (void)cancelImport:(id)sender
{
    [self->importCancelButton setEnabled:NO];
    [self->importProgressLabel setStringValue:NSLocalizedString(@"Cancelling...", @"")];
    [self->importOpQueue cancelAllOperations];
}

- (void)rescanROMs:(id)sender
{
    [self auditAsync];
}

#pragma mark - Callbacks

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

#pragma mark - Private methods

- (void)importAsync:(NSArray *)paths
{
    double maxValue = [self->importProgressBar maxValue] + [paths count];
    [self->importProgressBar setMaxValue:maxValue];
    
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSOperation *importOp = [NSBlockOperation blockOperationWithBlock:^{
            NSString *filename = [path lastPathComponent];
            NSString *label = [NSString stringWithFormat:NSLocalizedString(@"Importing %@...", @""),
                               [filename stringByDeletingPathExtension]];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // Update the label
                [self->importProgressLabel setStringValue:label];
                // Enable the cancel button
                [self->importCancelButton setEnabled:YES];
            }];
            
            NSString *dstPath = [[[FXAppDelegate sharedInstance] romPath] stringByAppendingPathComponent:filename];
            NSLog(@"Importing %@ as %@", filename, dstPath);
            
            // FIXME
            NSError *error = nil;
            [[NSFileManager defaultManager] copyItemAtPath:path
                                                    toPath:dstPath
                                                     error:&error];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // Update the progress bar
                [self->importProgressBar incrementBy:1.0];
            }];
        }];
        
        [self->importOpQueue addOperation:importOp];
    }];
    
    if ([paths count] > 0) {
        [self auditAsync];
    }
}

- (void)auditAsync
{
    [self->importProgressBar setMaxValue:[self->importProgressBar maxValue] + 1];
    
    NSBlockOperation* auditOp = [[NSBlockOperation alloc] init];
    
    // Make a weak reference to avoid a retain cycle
    // http://stackoverflow.com/questions/8113268/how-to-cancel-nsblockoperation
    __weak NSBlockOperation* weakOp = auditOp;
    
    [auditOp addExecutionBlock:^{
#ifdef DEBUG
        NSDate *started = [NSDate date];
        NSLog(@"Auditing sets...");
#endif
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // Update the label
            [self->importProgressLabel setStringValue:NSLocalizedString(@"Scanning...", @"")];
            // Enable the cancel button
            [self->importCancelButton setEnabled:YES];
        }];
        
        NSMutableDictionary *audits = [NSMutableDictionary dictionary];
        FXLoader *loader = [[FXLoader alloc] init];
        
        // Determine the increment amount (not including subsets)
        double incrementAmount = 1.0 / [_drivers count];
        
        // Begin the audit
        [_drivers enumerateObjectsUsingBlock:^(FXDriver *driver, NSUInteger idx, BOOL *stop) {
            NSError *parentError = nil;
            FXDriverAudit *parentDriverAudit = [loader auditDriver:driver
															 error:&parentError];
			
            if (parentError == nil) {
                [audits setObject:parentDriverAudit forKey:[driver name]];
            } else {
                NSLog(@"Error scanning archive %@: %@",
                      [driver name], [parentError description]);
            }
            
            if ([weakOp isCancelled]) {
                *stop = YES;
                return;
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // Update the label
                [self->importProgressBar incrementBy:incrementAmount];
            }];
            
            [[driver children] enumerateObjectsUsingBlock:^(FXDriver *sd, NSUInteger idx, BOOL *stop) {
                if ([weakOp isCancelled]) {
                    *stop = YES;
                    return;
                }
                
                // Go through the children as well
                NSError *childError = NULL;
				FXDriverAudit *childDriverAudit = [loader auditDriver:sd
																error:&childError];
                
                if (childError == nil) {
                    [audits setObject:childDriverAudit
							   forKey:[sd name]];
                } else {
                    NSLog(@"Error scanning archive %@: %@",
                          [sd name], [childError description]);
                }
            }];
        }];
        
        if ([weakOp isCancelled]) {
            return;
        }
        
        // Save the audit data to cache file
        NSString *auditCachePath = [self auditCachePath];
#ifdef DEBUG
        NSLog(@"Writing audit data to %@", auditCachePath);
#endif
        if (![NSKeyedArchiver archiveRootObject:audits
                                         toFile:auditCachePath]) {
            NSLog(@"Error writing to audit cache");
        }
        
        // Update audits
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self updateAudits:audits];
        }];
#ifdef DEBUG
        NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
    }];
    
    [self->importOpQueue addOperation:auditOp];
}

- (NSString *)auditCachePath
{
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    NSURL *supportURL = [app appSupportURL];
    
    return [[supportURL URLByAppendingPathComponent:@"audits.cache"] path];
}

- (void)identifyROMSets
{
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"Identifying sets...");
#endif
    
	[_drivers addObjectsFromArray:[[FXManifest sharedInstance] drivers]];
	
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
    
    [_drivers enumerateObjectsUsingBlock:^(FXDriver *driver, NSUInteger idx, BOOL *stop) {
        FXDriverAudit *audit = [audits objectForKey:[driver name]];
        [driver setAudit:audit];
        
        [[driver children] enumerateObjectsUsingBlock:^(FXDriver *sd, NSUInteger idx, BOOL *stop) {
            FXDriverAudit *subAudit = [audits objectForKey:[sd name]];
            [sd setAudit:subAudit];
        }];
    }];
    
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

@end
