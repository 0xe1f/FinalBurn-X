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
#import "FXDIPSwitchInfo.h"

@interface FXPreferencesController ()

- (void)emulationChangedNotification:(NSNotification *)notification;
- (void)resetInput:(FXROMSet *)set;

@end

@implementation FXPreferencesController

- (id)init
{
    if ((self = [super initWithWindowNibName:@"Preferences"]) != nil) {
        self->inputList = [NSMutableArray array];
        self->dipswitchList = [NSMutableArray array];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(emulationChangedNotification:)
                                                 name:FXEmulatorChanged
                                               object:nil];
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
    
    [self resetInput:[emulator romSet]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FXEmulatorChanged
                                                  object:nil];
}

#pragma mark - NSWindowController

- (void)windowDidLoad
{
    [toolbar setSelectedItemIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"selectedPreferencesTab"]];
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
    if (tableView == self->inputTableView) {
        return [self->inputList count];
    } else if (tableView == self->dipswitchTableView) {
        return [self->dipswitchList count];
    }
    
    return 0;
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    if (tableView == self->inputTableView) {
        FXInputInfo *inputInfo = [self->inputList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [inputInfo name];
        } else if ([[tableColumn identifier] isEqualToString:@"keyboard"]) {
            FXAppDelegate *app = [FXAppDelegate sharedInstance];
            FXEmulatorController *emulator = [app emulator];
            FXInput *input = [emulator input];
            FXInputMap *inputMap = [input inputMap];
            NSInteger keyCode = [inputMap keyCodeForDriverCode:[inputInfo code]];
            
            return [AKKeyCaptureView descriptionForKeyCode:keyCode];
        }
    } else if (tableView == self->dipswitchTableView) {
        FXDIPSwitchInfo *dipswitchInfo = [self->dipswitchList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [dipswitchInfo name];
        } else if ([[tableColumn identifier] isEqualToString:@"value"]) {
            // FIXME
//            FXAppDelegate *app = [FXAppDelegate sharedInstance];
//            FXEmulatorController *emulator = [app emulator];
//            FXInput *input = [emulator input];
//            FXInputMap *inputMap = [input inputMap];
//            NSInteger keyCode = [inputMap keyCodeForDriverCode:[inputInfo code]];
//            
//            return [AKKeyCaptureView descriptionForKeyCode:keyCode];
        }
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    if (tableView == self->inputTableView) {
        if ([[tableColumn identifier] isEqualToString:@"keyboard"]) {
            NSInteger keyCode = [AKKeyCaptureView keyCodeForDescription:object];
            FXInputInfo *inputInfo = [inputList objectAtIndex:row];
            
            FXAppDelegate *app = [FXAppDelegate sharedInstance];
            FXEmulatorController *emulator = [app emulator];
            FXInput *input = [emulator input];
            FXInputMap *inputMap = [input inputMap];
            [inputMap assignKeyCode:keyCode toDriverCode:[inputInfo code]];
        }
    } else if (tableView == self->dipswitchTableView) {
        // FIXME
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

#pragma mark - Actions

- (void)tabChanged:(id)sender
{
    NSToolbarItem *selectedItem = (NSToolbarItem *)sender;
    NSString *tabIdentifier = [selectedItem itemIdentifier];
    
    [toolbar setSelectedItemIdentifier:tabIdentifier];
    [[NSUserDefaults standardUserDefaults] setObject:tabIdentifier forKey:@"selectedPreferencesTab"];
}

#pragma mark - Private methods

- (void)emulationChangedNotification:(NSNotification *)notification
{
#ifdef DEBUG
    NSLog(@"emulationChangedNotification");
#endif
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
    
    [self resetInput:[emulator romSet]];
}

- (void)resetInput:(FXROMSet *)romSet
{
    [self->inputList removeAllObjects];
    [self->dipswitchList removeAllObjects];
    
    if (romSet != nil) {
        NSError *error = nil;
        NSArray *inputs = [FXInput inputsForDriver:[romSet archive]
                                             error:&error];
        
        if (error != nil) {
            // FIXME
        } else {
            [self->inputList addObjectsFromArray:inputs];
        }
        
        NSArray *dipswitches = [FXInput dipswitchesForDriver:[romSet archive]
                                                       error:&error];
        
        if (error != nil) {
            // FIXME
        } else {
            [self->dipswitchList addObjectsFromArray:dipswitches];
        }
    }
    
    [self->inputTableView setEnabled:[self->inputList count] > 0];
    [self->dipswitchTableView setEnabled:[self->dipswitchList count] > 0];
    
    [self->inputTableView reloadData];
    [self->dipswitchTableView reloadData];
}

@end
