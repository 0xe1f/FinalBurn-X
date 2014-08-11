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
- (NSDictionary *)auditROMSets;
- (void)updateAudits:(NSDictionary *)audits;

@end

@implementation FXLauncherController

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Launcher"])) {
        [self setDrivers:[NSMutableArray array]];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [self identifyROMSets];
    
    NSDictionary *audits;
    
    // Load the audit data from cache, if available
    NSString *auditCachePath = [self auditCachePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:auditCachePath isDirectory:nil]) {
        if ((audits = [NSKeyedUnarchiver unarchiveObjectWithFile:auditCachePath]) == nil) {
            NSLog(@"Error reading audit cache");
        }
    }
    
    // Nothing in cache, or error loading. Rescan
    if (audits == nil) {
        audits = [self auditROMSets];
    }
    
    // Update ROM sets with audit data
    [self updateAudits:audits];
    
    [self->driversTreeController rearrangeObjects];
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

#pragma mark - Private methods

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

- (NSDictionary *)auditROMSets
{
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"Auditing sets...");
#endif
    
    NSMutableDictionary *audits = [NSMutableDictionary dictionary];
    FXLoader *loader = [[FXLoader alloc] init];
    
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
        
        [[romSet subsets] enumerateObjectsUsingBlock:^(FXROMSet *subset, NSUInteger idx, BOOL *stop) {
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
    
    // Save the audit data to cache file
    NSString *auditCachePath = [self auditCachePath];
#ifdef DEBUG
    NSLog(@"Writing audit data to %@", auditCachePath);
#endif
    
    if (![NSKeyedArchiver archiveRootObject:audits
                                     toFile:auditCachePath]) {
        NSLog(@"Error writing to audit cache");
    }
    
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
    
    return audits;
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
