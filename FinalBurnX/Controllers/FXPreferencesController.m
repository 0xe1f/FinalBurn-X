/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/pokebyte/FinalBurn-X
 ** Copyright (C) 2014-2016 Akop Karapetyan
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
#import "FXPreferencesController.h"

#import "FXAppDelegate.h"
#import "FXInput.h"
#import "FXDIPSwitchGroup.h"
#import "FXManifest.h"
#import "FXInputConfig.h"
#import "FXInputConstants.h"
#import "FXButtonMap.h"
#import "FXJoyCaptureView.h"
#import "AKGamepadManager.h"

#pragma mark - FXButtonConfig

@implementation FXButtonConfig

@end

#pragma mark - FXPreferencesController

@interface FXPreferencesController ()

- (void) emulationChangedNotification:(NSNotification *)notification;

- (void) updateSpecifics;
- (void) updateDipSwitches;
- (void) sliderValueChanged:(NSSlider *) sender;
- (void) resetButtonList;
- (void) resetInputDevices;
- (NSString *) selectedInputDeviceId;

@end

@implementation FXPreferencesController
{
	NSMutableArray<FXButtonConfig *> *_inputList;
	NSMutableArray *dipSwitchList;
	AKKeyCaptureView *_keyCaptureView;
	FXJoyCaptureView *_joyCaptureView;
	NSMutableArray<NSDictionary *> *_inputDeviceList;
	NSMutableDictionary<NSString *, NSDictionary *> *_inputDeviceMap;
}

- (id) init
{
    if ((self = [super initWithWindowNibName:@"Preferences"]) != nil) {
        _inputList = [NSMutableArray new];
		_inputDeviceList = [NSMutableArray new];
		_inputDeviceMap = [NSMutableDictionary new];
        self->dipSwitchList = [NSMutableArray new];
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

	NSDictionary *gp = @{ @"id": @"keyboard",
						  @"title": NSLocalizedString(@"Keyboard", @"Device") };
	[_inputDeviceList addObject:gp];
	[_inputDeviceMap setObject:gp
						forKey:@"keyboard"];

	AKGamepadManager *gm = [AKGamepadManager sharedInstance];
	for (int i = 0, n = (int) [gm gamepadCount]; i < n; i++) {
		AKGamepad *gamepad = [gm gamepadAtIndex:i];
		NSString *key = [gamepad vendorProductString];
		NSDictionary *gp = @{ @"id": key,
							  @"title": [gamepad name] };

		[_inputDeviceList addObject:gp];
		[_inputDeviceMap setObject:gp
							forKey:key];
	}
	[self resetInputDevices];

	[[AKGamepadManager sharedInstance] addObserver:self];
}

- (void) dealloc
{
	[[AKGamepadManager sharedInstance] removeObserver:self];

	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FXEmulatorChanged
                                                  object:nil];
}

#pragma mark - NSWindowController

- (void) windowDidLoad
{
    [toolbar setSelectedItemIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"selectedPreferencesTab"]];
}

- (id) windowWillReturnFieldEditor:(NSWindow *) sender
						  toObject:(id) anObject
{
    if (anObject == inputTableView) {
		BOOL isKeyboard = [@"keyboard" isEqualToString:[self selectedInputDeviceId]];
		if (isKeyboard) {
			if (!_keyCaptureView) {
				_keyCaptureView = [AKKeyCaptureView new];
			}
			return _keyCaptureView;
		} else {
			if (!_joyCaptureView) {
				_joyCaptureView = [FXJoyCaptureView new];
			}
			return _joyCaptureView;
		}
    }
    
    return nil;
}

- (void) windowDidBecomeKey:(NSNotification *) notification
{
    [[AKKeyboardManager sharedInstance] addObserver:self];
}

- (void) windowDidResignKey:(NSNotification *) notification
{
    [[AKKeyboardManager sharedInstance] removeObserver:self];
}

#pragma mark - AKGamepadDelegate

- (void) gamepadDidConnect:(AKGamepad *) gamepad
{
	NSString *key = [gamepad vendorProductString];
	@synchronized (_inputDeviceList) {
		if (![_inputDeviceMap objectForKey:key]) {
			NSDictionary *gp = @{ @"id": key,
								  @"title": [gamepad name] };

			[_inputDeviceMap setObject:gp
								forKey:key];
			[_inputDeviceList addObject:gp];
		}
	}

	[self resetInputDevices];
}

- (void) gamepadDidDisconnect:(AKGamepad *) gamepad
{
	NSString *key = [gamepad vendorProductString];
	@synchronized (_inputDeviceList) {
		NSDictionary *gp = [_inputDeviceMap objectForKey:key];

		[_inputDeviceMap removeObjectForKey:key];
		[_inputDeviceList removeObject:gp];
	}
	
	[self resetInputDevices];
}

- (void) gamepad:(AKGamepad *) gamepad
		xChanged:(NSInteger) newValue
		  center:(NSInteger) center
	   eventData:(AKGamepadEventData *) eventData
{
	if ([[gamepad vendorProductString] isEqualToString:[self selectedInputDeviceId]]) {
		if ([[self window] firstResponder] == _joyCaptureView) {
			if (newValue < center) {
				[_joyCaptureView captureCode:FXGamepadLeft];
			} else if (newValue > center) {
				[_joyCaptureView captureCode:FXGamepadRight];
			}
		}
	}
}

- (void) gamepad:(AKGamepad *) gamepad
		yChanged:(NSInteger) newValue
		  center:(NSInteger) center
	   eventData:(AKGamepadEventData *) eventData
{
	if ([[gamepad vendorProductString] isEqualToString:[self selectedInputDeviceId]]) {
		if ([[self window] firstResponder] == _joyCaptureView) {
			if (newValue < center) {
				[_joyCaptureView captureCode:FXGamepadUp];
			} else if (newValue > center) {
				[_joyCaptureView captureCode:FXGamepadDown];
			}
		}
	}
}

- (void) gamepad:(AKGamepad *) gamepad
		  button:(NSUInteger) index
		  isDown:(BOOL) isDown
	   eventData:(AKGamepadEventData *) eventData
{
	if ([[gamepad vendorProductString] isEqualToString:[self selectedInputDeviceId]]) {
		if ([[self window] firstResponder] == _joyCaptureView) {
			[_joyCaptureView captureCode:FXMakeButton(index)];
		}
	}
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

- (id) tableView:(NSTableView *) tableView
objectValueForTableColumn:(NSTableColumn *) tableColumn
			 row:(NSInteger) row
{
    if (tableView == self->inputTableView) {
        FXButtonConfig *bc = [_inputList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
			return [bc title];
        } else if ([[tableColumn identifier] isEqualToString:@"button"]) {
			if ([@"keyboard" isEqualToString:[self selectedInputDeviceId]]) {
				return [AKKeyCaptureView descriptionForKeyCode:[bc deviceCode]];
			} else {
				return [FXJoyCaptureView descriptionForCode:[bc deviceCode]];
			}
        }
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

- (void) tableView:(NSTableView *) tableView
	setObjectValue:(id) object
	forTableColumn:(NSTableColumn *) tableColumn
			   row:(NSInteger) row
{
    if (tableView == self->inputTableView) {
		FXButtonConfig *bc = [_inputList objectAtIndex:row];
        if ([[tableColumn identifier] isEqualToString:@"button"]) {
			int deviceCode = FXMappingNotFound;
			NSString *inputDeviceId = [self selectedInputDeviceId];
			if ([@"keyboard" isEqualToString:inputDeviceId]) {
				int code = (int) [AKKeyCaptureView keyCodeForDescription:object];
				if (code != AKKeyNone) {
					deviceCode = code;
				}
			} else {
				int code = (int) [FXJoyCaptureView codeForDescription:object];
				if (code != FXGamepadNone) {
					deviceCode = code;
				}
			}
			
			[bc setDeviceCode:deviceCode];
			
			FXInput *input = [[[FXAppDelegate sharedInstance] emulator] input];
			[[[input config] mapWithId:inputDeviceId] mapDeviceCode:deviceCode
														virtualCode:[bc virtualCode]];
        }
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

- (void) keyStateChanged:(AKKeyEventData *) event
				  isDown:(BOOL) isDown
{
    if ([event hasKeyCodeEquivalent]) {
        if ([[self window] firstResponder] == _keyCaptureView) {
            BOOL isReturn = [event keyCode] == AKKeyCodeReturn || [event keyCode] == AKKeyCodeKeypadEnter;
            if (isReturn || !isDown) {
                [_keyCaptureView captureKeyCode:[event keyCode]];
            }
        }
    }
}

#pragma mark - Actions

- (void) inputDeviceDidChange:(id) sender
{
	[self resetButtonList];
}

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

- (NSString *) selectedInputDeviceId
{
	NSInteger index = [inputDevicesPopUp indexOfSelectedItem];
	if (index < [_inputDeviceList count]) {
		return [[_inputDeviceList objectAtIndex:index] objectForKey:@"id"];
	}

	return nil;
}

- (void) emulationChangedNotification:(NSNotification *)notification
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

- (void) resetButtonList
{
    [_inputList removeAllObjects];

	NSString *inputDeviceId = [self selectedInputDeviceId];
	BOOL isKeyboard = [@"keyboard" isEqualToString:inputDeviceId];
    FXEmulatorController *emulator = [[FXAppDelegate sharedInstance] emulator];
	FXButtonMap *map = [[[emulator input] config] mapWithId:inputDeviceId];

	[[[emulator driver] buttons] enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		if (isKeyboard) {
			FXButtonConfig *bc = [FXButtonConfig new];
			[bc setName:[b name]];
			[bc setTitle:[b title]];
			[bc setDeviceCode:[map deviceCodeMatching:[b code]]];
			[bc setVirtualCode:[b code]];
			[_inputList addObject:bc];
		} else if ([b playerIndex] == 1) {
			FXButtonConfig *bc = [FXButtonConfig new];
			[bc setName:[b name]];
			[bc setTitle:[b neutralTitle]];
			[bc setDeviceCode:[map deviceCodeMatching:[b code]]];
			[bc setVirtualCode:[b code]];
			[_inputList addObject:bc];
		}
	}];

    [self->inputTableView setEnabled:[_inputList count] > 0];
    [self->inputTableView reloadData];
}

- (void) resetInputDevices
{
	[inputDevicesPopUp removeAllItems];
	[_inputDeviceList enumerateObjectsUsingBlock:^(NSDictionary *gp, NSUInteger idx, BOOL *stop) {
		[inputDevicesPopUp addItemWithTitle:[gp objectForKey:@"title"]];
	}];
}

- (void) updateSpecifics
{
    [self updateDipSwitches];
    [self resetButtonList];
}

@end
