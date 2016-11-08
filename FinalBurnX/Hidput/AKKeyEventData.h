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
#import <Foundation/Foundation.h>

@interface AKKeyEventData : NSObject

@property (nonatomic, assign) NSInteger scanCode;
@property (nonatomic, assign) NSInteger keyCode;
@property (nonatomic, assign) NSUInteger modifierFlags;

- (BOOL) hasKeyCodeEquivalent;

@end

enum {
    AKKeyInvalid = 0xff,
    
    AKKeyCodeA = 0x00,
    AKKeyCodeB = 0x0b,
    AKKeyCodeC = 0x08,
    AKKeyCodeD = 0x02,
    AKKeyCodeE = 0x0e,
    AKKeyCodeF = 0x03,
    AKKeyCodeG = 0x05,
    AKKeyCodeH = 0x04,
    AKKeyCodeI = 0x22,
    AKKeyCodeJ = 0x26,
    AKKeyCodeK = 0x28,
    AKKeyCodeL = 0x25,
    AKKeyCodeM = 0x2e,
    AKKeyCodeN = 0x2d,
    AKKeyCodeO = 0x1f,
    AKKeyCodeP = 0x23,
    AKKeyCodeQ = 0x0c,
    AKKeyCodeR = 0x0f,
    AKKeyCodeS = 0x01,
    AKKeyCodeT = 0x11,
    AKKeyCodeU = 0x20,
    AKKeyCodeV = 0x09,
    AKKeyCodeW = 0x0d,
    AKKeyCodeX = 0x07,
    AKKeyCodeY = 0x10,
    AKKeyCodeZ = 0x06,
    
    AKKeyCode1 = 0x12,
    AKKeyCode2 = 0x13,
    AKKeyCode3 = 0x14,
    AKKeyCode4 = 0x15,
    AKKeyCode5 = 0x17,
    AKKeyCode6 = 0x16,
    AKKeyCode7 = 0x1a,
    AKKeyCode8 = 0x1c,
    AKKeyCode9 = 0x19,
    AKKeyCode0 = 0x1d,
    
    AKKeyCodeReturn = 0x24,
    AKKeyCodeEscape = 0x35,
    AKKeyCodeDelete = 0x75,
    AKKeyCodeBackspace = 0x33,

    AKKeyCodeTab = 0x30,
    AKKeyCodeSpacebar = 0x31,
    AKKeyCodeHyphen = 0x1b,
    AKKeyCodeEqualSign = 0x18,
    AKKeyCodeOpenBracket = 0x21,
    AKKeyCodeCloseBracket = 0x1e,
    AKKeyCodeBackslash = 0x2a,
    AKKeyCodeSemicolon = 0x29,
    AKKeyCodeQuote = 0x27,
    AKKeyCodeTilde = 0x32,
    AKKeyCodeComma = 0x2b,
    AKKeyCodePeriod = 0x2F,
    AKKeyCodeSlash = 0x2c,
    AKKeyCodeCapsLock = 0x39,
    
    AKKeyCodeF1 = 0x7a,
    AKKeyCodeF2 = 0x78,
    AKKeyCodeF3 = 0x63,
    AKKeyCodeF4 = 0x76,
    AKKeyCodeF5 = 0x60,
    AKKeyCodeF6 = 0x61,
    AKKeyCodeF7 = 0x62,
    AKKeyCodeF8 = 0x64,
    AKKeyCodeF9 = 0x65,
    AKKeyCodeF10 = 0x6d,
    AKKeyCodeF11 = 0x67,
    AKKeyCodeF12 = 0x6f,
    
    AKKeyCodeInsert = 0x72,
    AKKeyCodeHome = 0x73,
    AKKeyCodePageUp = 0x74,
    AKKeyCodeEnd = 0x77,
    AKKeyCodePageDown = 0x79,
    
    AKKeyCodeRightArrow = 0x7c,
    AKKeyCodeLeftArrow = 0x7b,
    AKKeyCodeDownArrow = 0x7d,
    AKKeyCodeUpArrow = 0x7e,
    
    AKKeyCodeNumLock = 0x47,
    AKKeyCodeKeypadSlash = 0x4b,
    AKKeyCodeKeypadAsterisk = 0x43,
    AKKeyCodeKeypadHyphen = 0x4e,
    AKKeyCodeKeypadPlus = 0x45,
    AKKeyCodeKeypadEnter = 0x4c,
    AKKeyCodeKeypadPeriod = 0x41,
    AKKeyCodeKeypadEqualSign = 0x51,
    
    AKKeyCodeKeypad1 = 0x53,
    AKKeyCodeKeypad2 = 0x54,
    AKKeyCodeKeypad3 = 0x55,
    AKKeyCodeKeypad4 = 0x56,
    AKKeyCodeKeypad5 = 0x57,
    AKKeyCodeKeypad6 = 0x58,
    AKKeyCodeKeypad7 = 0x59,
    AKKeyCodeKeypad8 = 0x5b,
    AKKeyCodeKeypad9 = 0x5c,
    AKKeyCodeKeypad0 = 0x52,
    
    AKKeyCodeApplication = 0x6e,
    AKKeyCodePrintScreen = 0x69,
    AKKeyCodeF14 = 0x6b,
    AKKeyCodeF15 = 0x71,
    AKKeyCodeMenu = 0x7f,
    AKKeyCodeSelect = 0x4c,

    AKKeyCodeLeftControl = 0x3b,
    AKKeyCodeLeftShift = 0x38,
    AKKeyCodeLeftAlt = 0x3a,
    AKKeyCodeLeftGUI = 0x37,
    AKKeyCodeRightControl = 0x3e,
    AKKeyCodeRightShift = 0x3c,
    AKKeyCodeRightAlt = 0x3d,
    AKKeyCodeRightGUI = 0x36,
};
