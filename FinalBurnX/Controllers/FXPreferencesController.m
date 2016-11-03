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
#import "FXPreferencesController.h"

#import "FXAppDelegate.h"
#import "FXInput.h"
#import "FXDIPSwitchGroup.h"
#import "FXManifest.h"

#pragma mark - FXButtonConfig

@implementation FXButtonConfig

@end

#pragma mark - FXPreferencesController

@interface FXPreferencesController ()

- (void)emulationChangedNotification:(NSNotification *)notification;

- (void)updateSpecifics;
- (void)updateInput;
- (void)updateDipSwitches;
- (void) sliderValueChanged:(NSSlider *) sender;

@end

@implementation FXPreferencesController
{
	NSMutableArray<FXButtonConfig *> *_inputList;
	NSMutableArray *dipSwitchList;
	AKKeyCaptureView *keyCaptureView;
}

- (id) init
{
    if ((self = [super initWithWindowNibName:@"Preferences"]) != nil) {
        _inputList = [NSMutableArray array];
        self->dipSwitchList = [NSMutableArray array];
    }
    
    return self;
}

- (void) awakeFromNib
{
	[volumeSlider setAction:@selector(sliderValueChanged:)];
	[volumeSlider setTarget:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(emulationChangedNotification:)
                                                 name:FXEmulatorChanged
                                               object:nil];
    
    [self updateSpecifics];
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
        return [_inputList count];
    } else if (tableView == self->dipswitchTableView) {
        return [self->dipSwitchList count];
    }
    
    return 0;
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    if (tableView == self->inputTableView) {
        FXButtonConfig *bc = [_inputList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
			return [bc title];
        } else if ([[tableColumn identifier] isEqualToString:@"keyboard"]) {
        }
		// FIXME
//        FXInputInfo *inputInfo = [self->inputList objectAtIndex:row];
//        if ([[tableColumn identifier] isEqualToString:@"name"]) {
//            return [inputInfo name];
//        } else if ([[tableColumn identifier] isEqualToString:@"keyboard"]) {
//            FXAppDelegate *app = [FXAppDelegate sharedInstance];
//            FXEmulatorController *emulator = [app emulator];
//            FXInput *input = [emulator input];
//            FXInputMap *inputMap = [input inputMap];
//            NSInteger keyCode = [inputMap keyCodeForDriverCode:[inputInfo code]];
//            
//            return [AKKeyCaptureView descriptionForKeyCode:keyCode];
//        }
    } else if (tableView == self->dipswitchTableView) {
        FXDIPSwitchGroup *group = [self->dipSwitchList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [group name];
        } else if ([[tableColumn identifier] isEqualToString:@"value"]) {
            NSPopUpButtonCell* cell = [tableColumn dataCell];
            [cell removeAllItems];
            
            __block NSUInteger enabledIndex = -1;
            [[group settings] enumerateObjectsUsingBlock:^(FXDIPSwitchSetting *setting, NSUInteger idx, BOOL *stop) {
                [cell addItemWithTitle:[setting name]];
                if ([setting isEnabled]) {
                    enabledIndex = idx;
                }
            }];
            
            return @(enabledIndex);
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
        }
			// FIXME
//            NSInteger keyCode = [AKKeyCaptureView keyCodeForDescription:object];
//            FXInputInfo *inputInfo = [self->inputList objectAtIndex:row];
//            
//            FXAppDelegate *app = [FXAppDelegate sharedInstance];
//            FXEmulatorController *emulator = [app emulator];
//            FXInput *input = [emulator input];
//            FXInputMap *inputMap = [input inputMap];
//            [inputMap assignKeyCode:keyCode toDriverCode:[inputInfo code]];
//        }
    } else if (tableView == self->dipswitchTableView) {
        if ([[tableColumn identifier] isEqualToString:@"value"]) {
            FXDIPSwitchGroup *dipSwitchGroup = [self->dipSwitchList objectAtIndex:row];
            FXDIPSwitchSetting *setting = [[dipSwitchGroup settings] objectAtIndex:[object intValue]];
            
            FXAppDelegate *app = [FXAppDelegate sharedInstance];
            FXEmulatorController *emulator = [app emulator];
            FXInput *input = [emulator input];
            [input setDipSwitchSetting:setting];
            [dipSwitchGroup enableSetting:setting];
        }
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

- (void)resetDipSwitchesClicked:(id)sender
{
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
    FXInput *input = [emulator input];
    
    [input resetDipSwitches];
    [self updateDipSwitches];
}

- (void) showNextTab:(id) sender
{
	NSArray<NSToolbarItem *> *items = [toolbar visibleItems];
	__block int selected = -1;
	[items enumerateObjectsUsingBlock:^(NSToolbarItem *item, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([[item itemIdentifier] isEqualToString:[toolbar selectedItemIdentifier]]) {
			selected = (int) idx;
			*stop = YES;
		}
	}];
	
	if (selected >= 0) {
		if (++selected >= [items count]) {
			selected = 0;
		}
		
		NSString *nextId = [[items objectAtIndex:selected] itemIdentifier];
		[toolbar setSelectedItemIdentifier:nextId];

		[[NSUserDefaults standardUserDefaults] setObject:nextId
												  forKey:@"selectedPreferencesTab"];
	}
}

- (void) showPreviousTab:(id) sender
{
	NSArray<NSToolbarItem *> *items = [toolbar visibleItems];
	__block int selected = -1;
	[items enumerateObjectsUsingBlock:^(NSToolbarItem *item, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([[item itemIdentifier] isEqualToString:[toolbar selectedItemIdentifier]]) {
			selected = (int) idx;
			*stop = YES;
		}
	}];
	
	if (selected >= 0) {
		if (--selected < 0) {
			selected = (int) [items count] - 1;
		}
		
		NSString *nextId = [[items objectAtIndex:selected] itemIdentifier];
		[toolbar setSelectedItemIdentifier:nextId];

		[[NSUserDefaults standardUserDefaults] setObject:nextId
												  forKey:@"selectedPreferencesTab"];
	}
}

- (void) sliderValueChanged:(NSSlider *) sender
{
	double range = [sender maxValue] - [sender minValue];
	double tickInterval = range / ([sender numberOfTickMarks] - 1);
	double relativeValue = [sender doubleValue] - [sender minValue];
	
	int nearestTick = round(relativeValue / tickInterval);
	double distance = relativeValue - nearestTick * tickInterval;
	
	if (fabs(distance) < 5.0)
		[sender setDoubleValue:[sender doubleValue] - distance];
}

#pragma mark - Private methods

- (void)emulationChangedNotification:(NSNotification *)notification
{
#ifdef DEBUG
    NSLog(@"emulationChangedNotification");
#endif
    
    [self updateSpecifics];
}

- (void)updateDipSwitches
{
    [self->dipSwitchList removeAllObjects];
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
    
    if (emulator != nil) {
        [self->dipSwitchList addObjectsFromArray:[[emulator input] dipSwitches]];
    }
    
    [self->resetDipSwitchesButton setEnabled:[self->dipSwitchList count] > 0];
    [self->dipswitchTableView setEnabled:[self->dipSwitchList count] > 0];
    [self->dipswitchTableView reloadData];
}

- (void)updateInput
{
    [_inputList removeAllObjects];
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    FXEmulatorController *emulator = [app emulator];
	
	[[[emulator driver] buttons] enumerateObjectsUsingBlock:^(FXButton *obj, NSUInteger idx, BOOL *stop) {
		FXButtonConfig *bc = [FXButtonConfig new];
		[bc setName:[obj name]];
		[bc setTitle:[obj title]];
	}];
	
    [self->inputTableView setEnabled:[_inputList count] > 0];
    [self->inputTableView reloadData];
}

- (void)updateSpecifics
{
    [self updateDipSwitches];
    [self updateInput];
}

@end
