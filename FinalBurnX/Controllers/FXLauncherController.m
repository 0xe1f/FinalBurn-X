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

- (void)reloadDrivers;

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
    [self reloadDrivers];
    
    [self->driversTreeController rearrangeObjects];
}

#pragma mark - Actions

- (void)launchGame:(id)sender
{
    NSTreeNode *selectedNode = [[self->driversTreeController selectedObjects] firstObject];
    FXDriverAudit *driverAudit = [selectedNode representedObject];
    if ([driverAudit isPlayable]) {
        FXAppDelegate *app = [FXAppDelegate sharedInstance];
        [app launch:[driverAudit archiveName]];
    }
}

#pragma mark - Private methods

- (void)reloadDrivers
{
#ifdef DEBUG
    NSDate *started = [NSDate date];
    NSLog(@"Loading drivers...");
#endif
    [[self drivers] removeAllObjects];
    
    FXLoader *loader = [[FXLoader alloc] init];
    NSDictionary *availableDrivers = [loader drivers];
    
    [availableDrivers enumerateKeysAndObjectsUsingBlock:^(NSNumber *parentDriverId, NSArray *children, BOOL *stop) {
        NSError *parentError = NULL;
        FXDriverAudit *parentDriverAudit = [loader auditDriver:[parentDriverId intValue]
                                                         error:&parentError];
        
        // FIXME: else if parentError != NULL..
        
        NSTreeNode *parentNode = [NSTreeNode treeNodeWithRepresentedObject:parentDriverAudit];
        
        [children enumerateObjectsUsingBlock:^(NSNumber *childDriverId, NSUInteger idx, BOOL *stop) {
            // Go through the children as well
            NSError *childError = NULL;
            FXDriverAudit *childDriverAudit = [loader auditDriver:[childDriverId intValue]
                                                            error:&childError];
            
            // FIXME: else if parentError != NULL..
            
            NSTreeNode *childNode = [NSTreeNode treeNodeWithRepresentedObject:childDriverAudit];
            [[parentNode mutableChildNodes] addObject:childNode];
        }];
        
        [[self drivers] addObject:parentNode];
    }];
#ifdef DEBUG
    NSLog(@"done (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

@end
