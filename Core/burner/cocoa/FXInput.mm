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

#import "FXAppDelegate.h"

#import "FXManifest.h"
#import "FXButtonMap.h"
#import "FXInputConfig.h"

#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

//#define DEBUG_KEY_STATE

@interface FXInput()

- (void) releaseAllKeys;
- (void) initializeInput;
- (int) dipSwitchOffset;

- (void) restoreInputMap;
- (void) saveInputMap;

- (void) restoreDipSwitches;
- (void) saveDipSwitches;

- (FXButtonMap *) defaultKeyboardMap;

@end

@implementation FXInput
{
	BOOL _hasFocus;
	BOOL _keyStates[256];
	FXDriver *_driver;
}

#pragma mark - Init, dealloc

- (instancetype) initWithDriver:(FXDriver *) driver
{
    if ((self = [super init]) != nil) {
		_driver = driver;
    }
    
    return self;
}

- (void) dealloc
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
    
    if (inputCode == FXInputReset) {
        BOOL isPressed = [self isResetPressed];
        if (isPressed) {
            [self setResetPressed:NO];
        }
        
        return isPressed;
    } else if (inputCode == FXInputDiagnostic) {
        BOOL isPressed = [self isTestPressed];
        if (isPressed) {
            [self setTestPressed:NO];
        }
        
        return isPressed;
    }
	
    int keyCode = [[_config keyboard] deviceCodeMatching:inputCode];
    if (keyCode == FXMappingNotFound) {
        return NO;
    }

    return _keyStates[keyCode];
}

- (void) initializeInput
{
    NSArray<FXButton *> *buttons = [_driver buttons];
    [buttons enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
        GameInp[idx].nInput = GIT_SWITCH;
		GameInp[idx].Input.Switch.nCode = [b code];
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
        _keyStates[[event keyCode]] = isDown;
    }
}

#pragma mark - Etc

- (void)setFocus:(BOOL)focus
{
    _hasFocus = focus;
    
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

- (void)restore
{
    [self restoreInputMap];
    [self restoreDipSwitches];
}

- (void)save
{
    [self saveInputMap];
    [self saveDipSwitches];
}

#pragma mark - Private

- (FXButtonMap *) defaultKeyboardMap
{
	BOOL usesSfLayout = [_driver usesStreetFighterLayout];
	FXButtonMap *map = [FXButtonMap new];
	[[_driver buttons] enumerateObjectsUsingBlock:^(FXButton *b, NSUInteger idx, BOOL *stop) {
		int code = [b code];
		if ([[b name] isEqualToString:@"p1 coin"]) {
			[map mapDeviceCode:AKKeyCode5 virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 start"]) {
			[map mapDeviceCode:AKKeyCode1 virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 up"]) {
			[map mapDeviceCode:AKKeyCodeUpArrow virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 down"]) {
			[map mapDeviceCode:AKKeyCodeDownArrow virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 left"]) {
			[map mapDeviceCode:AKKeyCodeLeftArrow virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 right"]) {
			[map mapDeviceCode:AKKeyCodeRightArrow virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 fire 1"]) {
			[map mapDeviceCode:AKKeyCodeA virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 fire 2"]) {
			[map mapDeviceCode:AKKeyCodeS virtualCode:code];
		} else if ([[b name] isEqualToString:@"p1 fire 3"]) {
			[map mapDeviceCode:AKKeyCodeD virtualCode:code];
		}
		
		if (usesSfLayout) {
			if ([[b name] isEqualToString:@"p1 fire 4"]) {
				[map mapDeviceCode:AKKeyCodeZ virtualCode:code];
			} else if ([[b name] isEqualToString:@"p1 fire 5"]) {
				[map mapDeviceCode:AKKeyCodeX virtualCode:code];
			} else if ([[b name] isEqualToString:@"p1 fire 6"]) {
				[map mapDeviceCode:AKKeyCodeC virtualCode:code];
			}
		} else {
			if ([[b name] isEqualToString:@"p1 fire 4"]) {
				[map mapDeviceCode:AKKeyCodeF virtualCode:code];
			}
		}
	}];
	
	return map;
}

- (void)restoreDipSwitches
{
    NSLog(@"FIXME: restore DIP");
}

- (void) restoreInputMap
{
    _config = nil;
    
    FXAppDelegate *app = [FXAppDelegate sharedInstance];
    NSString *file = [[_driver name] stringByAppendingPathExtension:@"input"];
    NSString *path = [[app inputMapPath] stringByAppendingPathComponent:file];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path isDirectory:nil]) {
        if (!(_config = [NSKeyedUnarchiver unarchiveObjectWithFile:path])) {
            NSLog(@"Error reading input configuration");
        }
    }
    
    if (!_config) {
		_config = [FXInputConfig new];
		[_config setKeyboard:[self defaultKeyboardMap]];
    }
}

- (void)saveDipSwitches
{
    NSLog(@"FIXME: save DIP");
}

- (void) saveInputMap
{
    if ([_config dirty]) {
        FXAppDelegate *app = [FXAppDelegate sharedInstance];
        NSString *file = [[_driver name] stringByAppendingPathExtension:@"input"];
        NSString *path = [[app inputMapPath] stringByAppendingPathComponent:file];
        
        if (![NSKeyedArchiver archiveRootObject:_config
                                         toFile:path]) {
            NSLog(@"Error writing to input configuration");
        }
    }
}

- (void)releaseAllKeys
{
    memset(_keyStates, 0, sizeof(_keyStates));
}

- (int)dipSwitchOffset
{
    int offset = 0;
    BurnDIPInfo bdi;
    for (int i = 0; BurnDrvGetDIPInfo(&bdi, i) == 0; i++) {
        if (bdi.nFlags == 0xF0) {
            offset = bdi.nInput;
            break;
        }
    }
    
    return offset;
}

- (void)resetDipSwitches
{
    int i = 0;
    BurnDIPInfo bdi;
    struct GameInp* pgi;
    
    int offset = [self dipSwitchOffset];
    while (BurnDrvGetDIPInfo(&bdi, i) == 0) {
        if (bdi.nFlags == 0xFF) {
            pgi = GameInp + bdi.nInput + offset;
            pgi->Input.Constant.nConst = (pgi->Input.Constant.nConst & ~bdi.nMask) | (bdi.nSetting & bdi.nMask);
        }
        i++;
    }
}

- (void)setDipSwitchSetting:(FXDIPSwitchSetting *)setting
{
    BurnDIPInfo bdi = {0, 0, 0, 0, NULL};
    struct GameInp *pgi;
    
    int offset = [self dipSwitchOffset];
    
    FXDIPSwitchGroup *group = [setting group];
    int nSel = [setting index];
    int j = 0;
    for (int i = 0; i <= nSel; i++) {
        do {
            BurnDrvGetDIPInfo(&bdi, [group index] + 1 + j++);
        } while (bdi.nFlags == 0);
    }
    
    pgi = GameInp + bdi.nInput + offset;
    pgi->Input.Constant.nConst = (pgi->Input.Constant.nConst & ~bdi.nMask) | (bdi.nSetting & bdi.nMask);
    if (bdi.nFlags & 0x40) {
        while (BurnDrvGetDIPInfo(&bdi, [group index] + 1 + j++) == 0) {
            if (bdi.nFlags == 0) {
                pgi = GameInp + bdi.nInput + offset;
                pgi->Input.Constant.nConst = (pgi->Input.Constant.nConst & ~bdi.nMask) | (bdi.nSetting & bdi.nMask);
            } else {
                break;
            }
        }
    }
}

- (NSArray *)dipSwitches
{
    NSMutableArray *groups = [NSMutableArray array];
    
    FXDIPSwitchGroup *group = nil;
    int dipSwitchIndex = -1;
    
    BurnDIPInfo dipGroup;
    int dipSwitchOffset = [self dipSwitchOffset];
    int dipSwitchCount = 0;
    
    for (int i = 0; BurnDrvGetDIPInfo(&dipGroup, i) == 0; i++) {
        if ((dipGroup.nFlags & 0xF0) == 0xF0) {
            if (dipGroup.nFlags == 0xFE || dipGroup.nFlags == 0xFD) {
                if ([group anyEnabled]) {
                    [groups addObject:group];
                }
                
                dipSwitchCount = dipGroup.nSetting;
                dipSwitchIndex = 0;
                
                group = [[FXDIPSwitchGroup alloc] init];
                [group setIndex:i];
                [group setFlags:dipGroup.nFlags];
                [group setName:[NSString stringWithCString:dipGroup.szText
                                                          encoding:NSUTF8StringEncoding]];
            }
        } else {
            BOOL isEnabled = NO;
            struct GameInp *pgi = GameInp + dipGroup.nInput + dipSwitchOffset;
            
            if ((pgi->Input.Constant.nConst & dipGroup.nMask) == dipGroup.nSetting) {
                isEnabled = YES;
                if ((dipGroup.nFlags & 0x0F) > 1) {
                    for (int j = 1; j < (dipGroup.nFlags & 0x0F); j++) {
                        BurnDIPInfo dipSetting;
                        BurnDrvGetDIPInfo(&dipSetting, i + j);
                        struct GameInp *dipInput = GameInp + dipSetting.nInput + dipSwitchOffset;
                        
                        if (dipGroup.nFlags & 0x80) {
                            if ((dipInput->Input.Constant.nConst & dipSetting.nMask) == dipSetting.nSetting) {
                                isEnabled = NO;
                                break;
                            }
                        } else {
                            if ((dipInput->Input.Constant.nConst & dipSetting.nMask) != dipSetting.nSetting) {
                                isEnabled = NO;
                                break;
                            }
                        }
                    }
                }
            }
            
            if (dipSwitchIndex < dipSwitchCount && dipGroup.szText != NULL) {
                FXDIPSwitchSetting *setting = [[FXDIPSwitchSetting alloc] init];
                [setting setIndex:dipSwitchIndex];
                [setting setGroup:group];
                [setting setEnabled:isEnabled];
                [setting setName:[NSString stringWithCString:dipGroup.szText
                                                    encoding:NSUTF8StringEncoding]];
                
                [[group settings] addObject:setting];
            }
            
            dipSwitchIndex++;
            i += (dipGroup.nFlags & 0x0F) - 1; // loop will add another increment
        }
    }
    
    if ([group anyEnabled]) {
        [groups addObject:group];
    }
    
    return groups;
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
