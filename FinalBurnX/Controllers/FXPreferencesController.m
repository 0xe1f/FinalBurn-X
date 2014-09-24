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
#import "FXPreferencesController.h"

#import "FXAppDelegate.h"
#import "FXInput.h"
#import "FXInputInfo.h"

@interface FXPreferencesController ()

@end

@implementation FXPreferencesController

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Preferences"]) != nil) {
        self->inputList = [NSMutableArray array];
    }
    
    return self;
}

- (void)tabChanged:(id)sender
{
    NSToolbarItem *selectedItem = (NSToolbarItem *)sender;
    NSString *tabIdentifier = [selectedItem itemIdentifier];
    
    [toolbar setSelectedItemIdentifier:tabIdentifier];
    [[NSUserDefaults standardUserDefaults] setObject:tabIdentifier forKey:@"selectedPreferencesTab"];
}

#pragma mark - NSWindowController

- (void)windowDidLoad
{
    [toolbar setSelectedItemIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"selectedPreferencesTab"]];
    
    [self resetInput];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender
                         toObject:(id)anObject
{
    if (anObject == inputTableView) {
        if (keyCaptureView == nil) {
            keyCaptureView = [[AKKeyCaptureView alloc] init];
        }
        
        return keyCaptureView;
    }
    
    return nil;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [[AKKeyboardManager sharedInstance] addObserver:self];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [[AKKeyboardManager sharedInstance] removeObserver:self];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self->inputList count];
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    if (tableView == self->inputTableView) {
        FXInputInfo *inputInfo = [self->inputList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [inputInfo name];
        } else if ([[tableColumn identifier] isEqualToString:@"assigned"]) {
            // FIXME
            return [AKKeyCaptureView descriptionForKeyCode:[inputInfo keyCode]];
        }
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"assigned"]) {
        NSInteger keyCode = [AKKeyCaptureView keyCodeForDescription:object];
        FXInputInfo *inputInfo = [inputList objectAtIndex:row];
        [inputInfo setKeyCode:keyCode];
    }
}

#pragma mark - AKKeyboardEventDelegate

- (void)keyStateChanged:(AKKeyEventData *)event
                 isDown:(BOOL)isDown
{
    if ([event hasKeyCodeEquivalent]) {
        if ([[self window] firstResponder] == keyCaptureView) {
            BOOL isReturn = [event keyCode] == AKKeyCodeReturn || [event keyCode] == AKKeyCodeKeypadEnter;
            if (isReturn || !isDown) {
                [keyCaptureView captureKeyCode:[event keyCode]];
            }
        }
    }
}

#pragma mark - Private methods

- (void)resetInput
{
    [self->inputList removeAllObjects];
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
    
    if (emulator != nil) {
        NSError *error = nil;
        NSArray *inputs = [FXInput inputsForDriver:[[emulator romSet] archive]
                                             error:&error];
        
        if (error != nil) {
            // FIXME
        }
        
        [self->inputList addObjectsFromArray:inputs];
    }
    
    [self->inputTableView reloadData];
}

@end
