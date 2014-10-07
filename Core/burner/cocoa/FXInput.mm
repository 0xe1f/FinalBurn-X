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
#import "FXInputInfo.h"

#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

//#define DEBUG_KEY_STATE

@interface FXInput()

- (void)releaseAllKeys;
- (void)initializeInput;

@end

@implementation FXInput

#pragma mark - Init, dealloc

- (instancetype)initWithROMSet:(FXROMSet *)romSet
{
    if ((self = [super init]) != nil) {
        [self setRomSet:romSet];
    }
    
    return self;
}

- (void)dealloc
{
    // Release all virtual keys
    [self releaseAllKeys];
    
    // Stop listening for key events
    [[AKKeyboardManager sharedInstance] removeObserver:self];
}

#pragma mark - Core callbacks

- (BOOL)isInputActiveForCode:(int)inputCode
{
    if (inputCode < 0) {
        return NO;
    }
    
    NSInteger keyCode = [self->_inputMap keyCodeForInputCode:inputCode];
    if (keyCode == AKKeyInvalid) {
        return NO;
    }
    
    return self->keyStates[keyCode];
}

- (void)initializeInput
{
    NSArray *inputCodes = [self->_inputMap inputCodes];
    [inputCodes enumerateObjectsUsingBlock:^(NSNumber *inputCode, NSUInteger idx, BOOL *stop) {
        GameInp[idx].nInput = GIT_SWITCH;
        GameInp[idx].Input.Switch.nCode = [inputCode unsignedShortValue];
    }];
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

- (void)restoreInputMap
{
    self->_inputMap = nil;
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    NSString *file = [[self->_romSet archive] stringByAppendingPathExtension:@"inp"];
    NSString *path = [[app inputMapPath] stringByAppendingPathComponent:file];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path isDirectory:nil]) {
        if ((self->_inputMap = [NSKeyedUnarchiver unarchiveObjectWithFile:path]) == nil) {
            NSLog(@"Error reading input configuration");
        }
    }
    
    if (self->_inputMap == nil) {
        self->_inputMap = [[FXInputMap alloc] initWithROMSet:self->_romSet];
        
        [self->_inputMap restoreDefaults];
        [self->_inputMap markClean];
    }
}

- (void)saveInputMap
{
    if ([self->_inputMap isDirty]) {
        FXAppDelegate *app = [FXAppDelegate sharedInstance];
        NSString *file = [[self->_romSet archive] stringByAppendingPathExtension:@"inp"];
        NSString *path = [[app inputMapPath] stringByAppendingPathComponent:file];
        
        if (![NSKeyedArchiver archiveRootObject:self->_inputMap
                                         toFile:path]) {
            NSLog(@"Error writing to input configuration");
        }
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
    FXInput *input = [[[FXAppDelegate sharedInstance] emulator] input];
    [input initializeInput];
    
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
