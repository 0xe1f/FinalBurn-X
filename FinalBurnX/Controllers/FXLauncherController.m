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
#import "FXLauncherController.h"

#import "FXEmulatorController.h"
#import "FXAppDelegate.h"

#import "FXLoader.h"

@interface FXLauncherController ()

- (NSString *)auditCachePath;
- (void)identifyROMSets;
- (void)updateAudits:(NSDictionary *)audits;
- (void)importAsync:(NSArray *)paths;
- (void)auditAsync;

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

- (BOOL)isArchiveSupported:(NSString *)path
{
    // Make sure it's a ZIP file
    if ([[path pathExtension] caseInsensitiveCompare:@"zip"] != NSOrderedSame) {
        return NO;
    }
    
    // Disallow importing from the library directory
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    NSString *romPath = [[FXAppDelegate sharedInstance] ROMPath];
    
    if ([parentPath caseInsensitiveCompare:romPath] == NSOrderedSame) {
        return NO;
    }
    
    // Make sure it's one of the supported ROM sets
    __block BOOL supported = NO;
    NSString *archive = [[path lastPathComponent] stringByDeletingPathExtension];
    [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
        if ([[romSet archive] caseInsensitiveCompare:archive] == NSOrderedSame) {
            supported = YES;
            *stop = YES;
        }
    }];
    
    return supported;
}

- (void)importArchives:(NSArray *)paths
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

- (void)launchGame:(id)sender
{
    FXROMSet *romSet = [[self->driversTreeController selectedObjects] lastObject];
    if ([[romSet audit] isPlayable]) {
        FXAppDelegate *app = [FXAppDelegate sharedInstance];
        [app launch:romSet];
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
            
            NSString *dstPath = [[[FXAppDelegate sharedInstance] ROMPath] stringByAppendingPathComponent:filename];
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
            [self->importProgressLabel setStringValue:NSLocalizedString(@"Scanning sets...", @"")];
            // Enable the cancel button
            [self->importCancelButton setEnabled:YES];
        }];
        
        NSMutableDictionary *audits = [NSMutableDictionary dictionary];
        FXLoader *loader = [[FXLoader alloc] init];
        
        // Determine the increment amount (not including subsets)
        double incrementAmount = 1.0 / [[self drivers] count];
        
        // Begin the audit
        [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
            NSError *parentError = nil;
            FXDriverAudit *parentDriverAudit = [loader auditSet:romSet
                                                          error:&parentError];
            
            if (parentError == nil) {
                [audits setObject:parentDriverAudit forKey:[romSet archive]];
            } else {
                NSLog(@"Error scanning archive %@: %@",
                      [romSet archive], [parentError description]);
            }
            
            if ([weakOp isCancelled]) {
                *stop = YES;
                return;
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // Update the label
                [self->importProgressBar incrementBy:incrementAmount];
            }];
            
            [[romSet subsets] enumerateObjectsUsingBlock:^(FXROMSet *subset, NSUInteger idx, BOOL *stop) {
                if ([weakOp isCancelled]) {
                    *stop = YES;
                    return;
                }
                
                // Go through the children as well
                NSError *childError = NULL;
                FXDriverAudit *childDriverAudit = [loader auditSet:subset
                                                             error:&childError];
                
                if (childError == nil) {
                    [audits setObject:childDriverAudit forKey:[subset archive]];
                } else {
                    NSLog(@"Error scanning archive %@: %@",
                          [subset archive], [childError description]);
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
    
    FXLoader *loader = [[FXLoader alloc] init];
    [[self drivers] addObjectsFromArray:[loader romSets]];
    
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
    
    [[self drivers] enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
        FXDriverAudit *audit = [audits objectForKey:[romSet archive]];
        [romSet setAudit:audit];
    }];
    
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

@end
