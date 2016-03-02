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

#import "FXInputState.h"
#import "FXEmulator.h"

@implementation FXInput
{
	unsigned char _states[256];
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

- (void) releaseAll
{
    memset(self->_states, 0, sizeof(self->_states));
}

#pragma mark - Public

- (void) updateState:(FXInputState *) state
{
	[state copyToBuffer:self->_states
			   maxBytes:sizeof(self->_states)];
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
	return [input isInputActiveForCode:nCode] == YES;
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
