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
#import "FXInput.h"

#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

#import "FXEmulator.h"
#import "FXInputMap.h"

@interface FXInput ()

- (void) releaseAll;

@end

@implementation FXInput
{
	unsigned char _states[256];
	FXInputMap *_map;
}

#pragma mark - Init, dealloc

- (instancetype) init
{
    if ((self = [super init]) != nil) {
		memset(self->_states, 0, sizeof(self->_states));
    }
    
    return self;
}

#pragma mark - Core callbacks

- (void) initCore
{
	struct BurnInputInfo bii;
	struct BurnDriver *driver = pDriver[nBurnDrvActive];
	for (int i = 0; i < 0x1000; i++) {
		if (driver->GetInputInfo(&bii, i)) {
			break;
		}
		
		if (bii.nType == BIT_DIGITAL) {
			GameInp[i].nInput = GIT_SWITCH;
			GameInp[i].Input.Switch.nCode = i + 1;
		}
	}
}

- (BOOL) isInputActiveForCode:(int) inputCode
{
	return self->_states[inputCode] != 0;
}

#pragma mark - AKKeyboardEventDelegate

- (void) keyStateChanged:(AKKeyEventData *) event
				  isDown:(BOOL) isDown
{
#ifdef DEBUG_KEY_STATE
	if (isDown) {
		NSLog(@"keyboardKeyDown: 0x%lx", [event keyCode]);
	} else {
		NSLog(@"keyboardKeyUp: 0x%lx", [event keyCode]);
	}
#endif
	
	// Don't generate a KeyDown if Command is pressed
	if (([event modifierFlags] & NSCommandKeyMask) == 0 || !isDown) {
		NSInteger virtualCode = [self->_map virtualCodeForKeyCode:[event keyCode]];
		if (virtualCode > 0 && virtualCode < 256) {
			self->_states[virtualCode] = isDown;
		}
	}
}

#pragma mark - Public

- (void) startTrackingInputWithMap:(FXInputMap *) map
{
#ifdef DEBUG
	NSLog(@"FXInput: startTracking");
#endif
	self->_map = map;
	[[AKKeyboardManager sharedInstance] addObserver:self];
}

- (void) stopTrackingInput
{
#ifdef DEBUG
	NSLog(@"FXInput: stopTracking");
#endif
	[[AKKeyboardManager sharedInstance] removeObserver:self];
	[self releaseAll];
}

#pragma mark - Private

- (void) releaseAll
{
	memset(self->_states, 0, sizeof(self->_states));
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaInputInit()
{
	[[[FXEmulator sharedInstance] input] initCore];
	return 0;
}

static int cocoaInputStart()
{
	return 0;
}

static int cocoaInputState(int nCode)
{
	FXInput *input = [[FXEmulator sharedInstance] input];
	return [input isInputActiveForCode:nCode];
}

struct InputInOut InputInOutCocoa = {
    cocoaInputInit,
    NULL,
    NULL,
    cocoaInputStart,
    cocoaInputState,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    _T("Cocoa Input"),
};
