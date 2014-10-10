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
#import "FXDIPSwitchInfo.h"

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


+ (NSArray *)inputsForDriver:(NSString *)archive
                       error:(NSError **)error
{
    int driverId = [FXROMSet driverIndexOfArchive:archive];
    if (driverId == -1) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"org.akop.fbx.Emulation"
                                         code:0
                                     userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"ROM set not recognized", @"") }];
        }
        
        return nil;
    }
    
    NSMutableArray *inputs = [NSMutableArray array];
    
    struct BurnInputInfo bii;
    for (int i = 0; i < 0x1000; i++) {
        if (pDriver[driverId]->GetInputInfo(&bii, i)) {
            break;
        }
        
        if (bii.nType == BIT_DIGITAL) {
            FXInputInfo *inputInfo = [[FXInputInfo alloc] initWithBurnInputInfo:&bii];
            
            int inputCode;
            if ([[inputInfo code] isEqualToString:@"reset"]) {
                inputCode = FXInputReset;
            } else if ([[inputInfo code] isEqualToString:@"diag"]) {
                inputCode = FXInputDiagnostic;
            } else {
                inputCode = i + 1;
            }
            
            [inputInfo setInputCode:inputCode];
            [inputs addObject:inputInfo];
        }
    }
    
    return inputs;
}

+ (NSArray *)dipswitchesForDriver:(NSString *)archive
                            error:(NSError **)error
{
    int driverId = [FXROMSet driverIndexOfArchive:archive];
    if (driverId == -1) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"org.akop.fbx.Emulation"
                                         code:0
                                     userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"ROM set not recognized", @"") }];
        }
        
        return nil;
    }
    
    NSMutableArray *switches = [NSMutableArray array];
    
    BurnDIPInfo bdi;
    FXDIPSwitchInfo *dipSwitchInfo = nil;
    
    int firstDipSwitchOffset = -1;
    int lastDipSwitchOffset = -1;
    
    if (pDriver[driverId]->GetDIPInfo != NULL) {
        for (int i = 0;;) {
            if (pDriver[driverId]->GetDIPInfo(&bdi, i)) {
                break;
            }
            
            if ((bdi.nFlags & 0xF0) == 0xF0) {
                if (firstDipSwitchOffset == -1) {
                    firstDipSwitchOffset = i;
                }
                lastDipSwitchOffset = i;
                
                if (bdi.nFlags == 0xFE || bdi.nFlags == 0xFD) {
                    dipSwitchInfo = [[FXDIPSwitchInfo alloc] init];
                    [dipSwitchInfo setFlags:bdi.nFlags];
                    [dipSwitchInfo setName:[NSString stringWithCString:bdi.szText
                                                              encoding:NSUTF8StringEncoding]];
                    
                    [switches addObject:dipSwitchInfo];
                }
                
                i++;
                
                NSLog(@" *** -- %@: %s (0x%x) %d", [dipSwitchInfo name], bdi.szText, bdi.nFlags, bdi.nInput);
            } else {
                BurnInputInfo bii;
                pDriver[driverId]->GetInputInfo(&bii, bdi.nInput + firstDipSwitchOffset);
                
                if ((*bii.pVal & bdi.nMask) == bdi.nSetting) {
                    if ((bdi.nFlags & 0x0F) <= 1) {
                        NSLog(@"YES! %s", bdi.szText);
                    } else {
                        int zoo = 1;
                        for (int j = 1; j < (bdi.nFlags & 0x0F); j++) {
                            BurnDIPInfo boodoo;
                            BurnInputInfo beeeee;
                            pDriver[driverId]->GetDIPInfo(&boodoo, i + j);
                            pDriver[driverId]->GetInputInfo(&beeeee, boodoo.nInput + firstDipSwitchOffset);

                            if (bdi.nFlags & 0x80) {
                                if ((*beeeee.pVal & boodoo.nMask) == boodoo.nSetting) {
                                    zoo = 0;
                                }
                            } else {
                                if ((*beeeee.pVal & boodoo.nMask) != boodoo.nSetting) {
                                    zoo = 0;
                                }
                            }
                        }
                        
                        if (!zoo)
                            NSLog(@"NO! %s", bdi.szText);
                        else
                            NSLog(@"YES! %s", bdi.szText);
                    }
//                    NSLog(@"   > 0x%x -- %@: %s (0x%x) %d", bdi.nFlags & 0x0f, [dipSwitchInfo name], bdi.szText, bdi.nFlags, bdi.nInput);
                } else {
                    NSLog(@"NO!!!!! %s", bdi.szText);
                }
                
//                if (bii.nType & BIT_GROUP_CONSTANT) {							// Further initialisation for constants/DIPs
//                    pgi->nInput = GIT_CONSTANT;
//                    pgi->Input.Constant.nConst = *bii.pVal;
//                }
                ////
                
                i += (bdi.nFlags & 0x0F);
            }
        }
    }
    
    return switches;
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
