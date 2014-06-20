//
//  FXInput.m
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/18/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "FXInput.h"

#import "AKAppDelegate.h"

#import "burner.h"

//#define DEBUG_KEY_STATE

@interface FXInput()

- (void)releaseAllKeys;

@end

@implementation FXInput

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

#pragma mark - Core callbacks

- (void)startCapture
{
}

- (BOOL)isInputActiveForCode:(int)code
{
    if (code < 0) {
        return NO;
    }
    
    switch(code)
	{
    case 0x02: // start
        return self->keyStates[0x12];
    case 0x06: // coin
        return self->keyStates[0x17];
    }
    
    /*
     if (nCode < 0x100) {
     if (ReadKeyboard() != 0) {							// Check keyboard has been read - return not pressed on error
     return 0;
     }
     return SDL_KEY_DOWN(nCode);							// Return key state
     }
     
     if (nCode < 0x4000) {
     return 0;
     }
     
     if (nCode < 0x8000) {
     // Codes 4000-8000 = Joysticks
     int nJoyNumber = (nCode - 0x4000) >> 8;
     
     // Find the joystick state in our array
     return JoystickState(nJoyNumber, nCode & 0xFF);
     }
     
     if (nCode < 0xC000) {
     // Codes 8000-C000 = Mouse
     if ((nCode - 0x8000) >> 8) {						// Only the system mouse is supported by SDL
     return 0;
     }
     if (ReadMouse() != 0) {								// Error polling the mouse
     return 0;
     }
     return CheckMouseState(nCode & 0xFF);
     }
     */
    
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

- (void)releaseAllKeys
{
    memset(self->keyStates, 0, sizeof(self->keyStates));
}

@end

#pragma mark - FinalBurn C++ callbacks

int cocoaInputInit()
{
	return 0;
}

int cocoaInputExit()
{
	return 0;
}

int cocoaInputSetCooperativeLevel(bool bExclusive, bool bForeGround)
{
	return 0;
}

int cocoaInputStart()
{
    FXInput *input = [[[AKAppDelegate sharedInstance] emulator] input];
    [input startCapture];
    
	return 0;
}

int cocoaInputState(int nCode)
{
    FXInput *input = [[[AKAppDelegate sharedInstance] emulator] input];
	return [input isInputActiveForCode:nCode] == YES;
}

int cocoaInputJoystickAxis(int i, int nAxis)
{
    return 0;
}

int cocoaInputMouseAxis(int i, int nAxis)
{
	return 0;
}

int cocoaInputFind(bool createBaseline)
{
	return -1;
}

int cocoaInputGetControlName(int nCode, TCHAR* pszDeviceName, TCHAR* pszControlName)
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
    "Cocoa Input",
};
