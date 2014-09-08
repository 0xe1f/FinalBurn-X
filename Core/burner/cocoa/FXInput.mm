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
#import "FXInput.h"

#import "FXAppDelegate.h"

#import "burner.h"

//#define DEBUG_KEY_STATE

@interface FXInput()

- (void)releaseAllKeys;

@end

@implementation FXInput

#pragma mark - Init, dealloc

- (void)dealloc
{
    // Release all virtual keys
    [self releaseAllKeys];
    
    // Stop listening for key events
    [[AKKeyboardManager sharedInstance] removeObserver:self];
}

#pragma mark - Core callbacks

- (BOOL)isInputActiveForCode:(int)code
{
    if (code < 0) {
        return NO;
    }
    
    switch(code)
	{
    case FBK_1: // start
        return self->keyStates[AKKeyCode1];
    case FBK_5: // coin
        return self->keyStates[AKKeyCode5];
    case FBK_A:
        return self->keyStates[AKKeyCodeA];
    case FBK_S:
        return self->keyStates[AKKeyCodeS];
    case FBK_D:
        return self->keyStates[AKKeyCodeD];
    case FBK_F:
        return self->keyStates[AKKeyCodeF];
    case FBK_Z:
        return self->keyStates[AKKeyCodeZ];
    case FBK_X:
        return self->keyStates[AKKeyCodeX];
    case FBK_C:
        return self->keyStates[AKKeyCodeC];
    case FBK_V:
        return self->keyStates[AKKeyCodeV];
    case FBK_UPARROW:
        return self->keyStates[AKKeyCodeUpArrow];
    case FBK_DOWNARROW:
        return self->keyStates[AKKeyCodeDownArrow];
    case FBK_LEFTARROW:
        return self->keyStates[AKKeyCodeLeftArrow];
    case FBK_RIGHTARROW:
        return self->keyStates[AKKeyCodeRightArrow];
    case FBK_F1:
        return self->keyStates[AKKeyCodeF1];
    case FBK_F2: {
        BOOL isPressed = [self isTestPressed];
        if (isPressed) {
            [self setTestPressed:NO];
        }
        
        return isPressed;
    }
    case FBK_F3: {
        BOOL isPressed = [self isResetPressed];
        if (isPressed) {
            [self setResetPressed:NO];
        }
        
        return isPressed;
    }
    case FBK_F4:
        return self->keyStates[AKKeyCodeF4];
    case FBK_F5:
        return self->keyStates[AKKeyCodeF5];
    }
    
    return NO;
}

#pragma mark - AKKeyboardEventDelegate

- (void)keyStateChanged:(AKKeyEventData *)event
                 isDown:(BOOL)isDown
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
        self->keyStates[[event keyCode]] = isDown;
    }
}

#pragma mark - Etc

- (void)setFocus:(BOOL)focus
{
    hasFocus = focus;
    
    if (!focus) {
#ifdef DEBUG
        NSLog(@"FXInput: -Focus");
#endif
        // Emulator has lost focus - release all virtual keys
        [self releaseAllKeys];
        
        // Stop listening for key events
        [[AKKeyboardManager sharedInstance] removeObserver:self];
    } else {
#ifdef DEBUG
        NSLog(@"FXInput: +Focus");
#endif
        // Start listening for key events
        [[AKKeyboardManager sharedInstance] addObserver:self];
    }
}

- (void)releaseAllKeys
{
    memset(self->keyStates, 0, sizeof(self->keyStates));
}

@end

#pragma mark - FinalBurn callbacks

static int cocoaInputInit()
{
	return 0;
}

static int cocoaInputExit()
{
	return 0;
}

static int cocoaInputSetCooperativeLevel(bool bExclusive, bool bForeGround)
{
	return 0;
}

static int cocoaInputStart()
{
	return 0;
}

static int cocoaInputState(int nCode)
{
    FXInput *input = [[[FXAppDelegate sharedInstance] emulator] input];
	return [input isInputActiveForCode:nCode] == YES;
}

static int cocoaInputJoystickAxis(int i, int nAxis)
{
    return 0;
}

static int cocoaInputMouseAxis(int i, int nAxis)
{
	return 0;
}

static int cocoaInputFind(bool createBaseline)
{
	return -1;
}

static int cocoaInputGetControlName(int nCode, TCHAR* pszDeviceName, TCHAR* pszControlName)
{
	if (pszDeviceName) {
		pszDeviceName[0] = _T('\0');
	}
	if (pszControlName) {
		pszControlName[0] = _T('\0');
	}
    
	return 0;
}

struct InputInOut InputInOutCocoa = {
    cocoaInputInit,
    cocoaInputExit,
    cocoaInputSetCooperativeLevel,
    cocoaInputStart,
    cocoaInputState,
    cocoaInputJoystickAxis,
    cocoaInputMouseAxis,
    cocoaInputFind,
    cocoaInputGetControlName,
    NULL,
    _T("Cocoa Input"),
};
