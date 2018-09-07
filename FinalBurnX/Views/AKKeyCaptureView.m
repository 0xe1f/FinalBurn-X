/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
 **
 ** Portions of code from ShortcutRecorder by various contributors
 ** http://wafflesoftware.net/shortcut/
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
#import <Carbon/Carbon.h>

#import "AKKeyCaptureView.h"

@interface AKKeyCaptureView ()

- (NSRect)unmapRect;
- (BOOL)canUnmap;

@end

@implementation AKKeyCaptureView

#define CMKeyLeftCommand      55
#define CMKeyRightCommand     54
#define CMKeyFunctionModifier 63

#define CMCharAsString(x) [NSString stringWithFormat:@"%C", (unsigned short)x]

static NSMutableDictionary *keyCodeLookupTable;
static NSMutableDictionary *reverseKeyCodeLookupTable;
static NSArray *keyCodesToIgnore;

+ (void)initialize
{
    keyCodesToIgnore = [[NSArray alloc] initWithObjects:
                        
                        // Ignore the function modifier key (needed on MacBooks)
                        
                        @CMKeyFunctionModifier,
                        
                        // Ignore the Command modifier keys - they're used
                        // for shortcuts
                        
                        @CMKeyLeftCommand,
                        @CMKeyRightCommand,
                        
                        nil];

    keyCodeLookupTable = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                          
                          // These seem to be unused. Included here to avoid
                          // creating collisions in reverseKeyCodeLookupTable
                          // with identical names
                          
                          @"",    @0x66,
                          @"",    @0x68,
                          @"",    @0x6c,
                          @"",    @0x6e,
                          @"",    @0x70,
                          
                          // Well-known keys
                          
                          @"F1",  @0x7a,
                          @"F2",  @0x78,
                          @"F3",  @0x63,
                          @"F4",  @0x76,
                          @"F5",  @0x60,
                          @"F6",  @0x61,
                          @"F7",  @0x62,
                          @"F8",  @0x64,
                          @"F9",  @0x65,
                          @"F10", @0x6d,
                          @"F11", @0x67,
                          @"F12", @0x6f,
                          NSLocalizedString(@"Print Screen", @"Mac Key"), @0x69,
                          @"F14", @0x6b,
                          @"F15", @0x71,
                          @"F16", @0x6a,
                          @"F17", @0x40,
                          @"F18", @0x4f,
                          @"F19", @0x50,
                          
                          NSLocalizedString(@"Caps Lock", @"Mac Key"), @0x39,
                          NSLocalizedString(@"Space", @"Mac Key"),     @0x31,
                          
                          [NSString stringWithFormat:NSLocalizedString(@"Left %C", @"Mac Key"), kShiftUnicode],    @0x38,
                          [NSString stringWithFormat:NSLocalizedString(@"Right %C", @"Mac Key"), kShiftUnicode],   @0x3c,
                          [NSString stringWithFormat:NSLocalizedString(@"Left %C", @"Mac Key"), kControlUnicode],  @0x3b,
                          [NSString stringWithFormat:NSLocalizedString(@"Right %C", @"Mac Key"), kControlUnicode], @0x3e,
                          [NSString stringWithFormat:NSLocalizedString(@"Left %C", @"Mac Key"), kOptionUnicode],   @0x3a,
                          [NSString stringWithFormat:NSLocalizedString(@"Right %C", @"Mac Key"), kOptionUnicode],  @0x3d,
                          [NSString stringWithFormat:NSLocalizedString(@"Left %C", @"Mac Key"), kCommandUnicode],  @0x37,
                          [NSString stringWithFormat:NSLocalizedString(@"Right %C", @"Mac Key"), kCommandUnicode], @0x36,
                          
                          NSLocalizedString(@"Keypad .", @"Mac Key"),     @0x41,
                          NSLocalizedString(@"Keypad *", @"Mac Key"),     @0x43,
                          NSLocalizedString(@"Keypad +", @"Mac Key"),     @0x45,
                          NSLocalizedString(@"Keypad /", @"Mac Key"),     @0x4b,
                          NSLocalizedString(@"Keypad -", @"Mac Key"),     @0x4e,
                          NSLocalizedString(@"Keypad =", @"Mac Key"),     @0x51,
                          NSLocalizedString(@"Keypad 0", @"Mac Key"),     @0x52,
                          NSLocalizedString(@"Keypad 1", @"Mac Key"),     @0x53,
                          NSLocalizedString(@"Keypad 2", @"Mac Key"),     @0x54,
                          NSLocalizedString(@"Keypad 3", @"Mac Key"),     @0x55,
                          NSLocalizedString(@"Keypad 4", @"Mac Key"),     @0x56,
                          NSLocalizedString(@"Keypad 5", @"Mac Key"),     @0x57,
                          NSLocalizedString(@"Keypad 6", @"Mac Key"),     @0x58,
                          NSLocalizedString(@"Keypad 7", @"Mac Key"),     @0x59,
                          NSLocalizedString(@"Keypad 8", @"Mac Key"),     @0x5b,
                          NSLocalizedString(@"Keypad 9", @"Mac Key"),     @0x5c,
                          NSLocalizedString(@"Keypad Enter", @"Mac Key"), @0x4c,
                          
                          NSLocalizedString(@"Insert", "Mac Key"),    @0x72, // Insert
                          CMCharAsString(0x232B),         @0x33, // Backspace
                          CMCharAsString(0x2326),         @0x75, // Delete
                          NSLocalizedString(@"Num Lock", "Mac Key"),  @0x47, // Numpad
                          CMCharAsString(0x2190),         @0x7b, // Cursor Left
                          CMCharAsString(0x2192),         @0x7c, // Cursor Right
                          CMCharAsString(0x2191),         @0x7e, // Cursor Up
                          CMCharAsString(0x2193),         @0x7d, // Cursor Down
                          NSLocalizedString(@"Home", "Mac Key"),      @0x73, // Home
                          NSLocalizedString(@"End", "Mac Key"),       @0x77, // End
                          NSLocalizedString(@"Escape", "Mac Key"),    @0x35, // Escape
                          NSLocalizedString(@"Page Down", "Mac Key"), @0x79, // Page Down
                          NSLocalizedString(@"Page Up", "Mac Key"),   @0x74, // Page Up
                          CMCharAsString(0x21A9),         @0x24, // Return R-L
                          CMCharAsString(0x21E5),         @0x30, // Tab
                          
                          nil];
    
    // Get names for the remaining keys by going through the list of codes
    
	OSStatus err;
	TISInputSourceRef tisSource = TISCopyCurrentKeyboardInputSource();
    
    if (tisSource) {
        CFDataRef layoutData;
        UInt32 keysDown = 0;
        layoutData = (CFDataRef)TISGetInputSourceProperty(tisSource,
                                                          kTISPropertyUnicodeKeyLayoutData);
        
        CFRelease(tisSource);
        
        // For non-unicode layouts such as Chinese, Japanese, and
        // Korean, get the ASCII capable layout
        
        if (!layoutData) {
            tisSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
            layoutData = (CFDataRef)TISGetInputSourceProperty(tisSource,
                                                              kTISPropertyUnicodeKeyLayoutData);
            CFRelease(tisSource);
        }
        
        if (layoutData) {
            const UCKeyboardLayout *keyLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
            
            UniCharCount length = 4, realLength;
            UniChar chars[4];
            
            for (int keyCode = 0; keyCode < 255; keyCode++) {
                NSNumber *keyCodeObj = @(keyCode);
                
                // Skip through codes we already know
                if ([keyCodeLookupTable objectForKey:keyCodeObj]) {
                    continue;
                }
                
                err = UCKeyTranslate(keyLayout,
                                     keyCode,
                                     kUCKeyActionDisplay,
                                     0,
                                     LMGetKbdType(),
                                     kUCKeyTranslateNoDeadKeysBit,
                                     &keysDown,
                                     length,
                                     &realLength,
                                     chars);
                
                if (err == noErr && realLength > 0) {
                    NSString *keyName = [[NSString stringWithCharacters:chars length:1] uppercaseString];
                    [keyCodeLookupTable setObject:keyName forKey:keyCodeObj];
                }
            }
        }
    }
    
    // Generate reverse lookup table
    reverseKeyCodeLookupTable = [[NSMutableDictionary alloc] init];
    
    [keyCodeLookupTable enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSNumber *keyCodeObj = key;
        NSString *keyName = obj;
        NSNumber *existingCode;
        
        if ([keyName length] > 0) {
            if ((existingCode = [reverseKeyCodeLookupTable objectForKey:keyName])) {
                NSLog(@"reverseKeyCodeLookupTable conflict: name: '%@' code: %@ (existing: %@)",
                      keyName, keyCodeObj, existingCode);
                
                return;
            }
            
            [reverseKeyCodeLookupTable setObject:keyCodeObj forKey:keyName];
        }
    }];
}

#pragma mark - Input events

- (BOOL)becomeFirstResponder
{
    if ([super becomeFirstResponder]) {
        [self setEditable:NO];
        [self setSelectable:NO];
        
        return YES;
    }
    
    return NO;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];
    
    if ([self canUnmap]) {
        NSPoint mousePosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        if (NSPointInRect(mousePosition, [self unmapRect])) {
            [self captureKeyCode:AKKeyNone];
        }
    }
}

- (void)keyDown:(NSEvent *)theEvent
{
}

- (void)keyUp:(NSEvent *)theEvent
{
}

#pragma mark - Private methods

- (BOOL)captureKeyCode:(NSInteger)keyCode
{
    if ([keyCodesToIgnore containsObject:@(keyCode)]) {
        return NO;
    }

    NSString *keyName = [AKKeyCaptureView descriptionForKeyCode:keyCode];
    if (!keyName) {
        keyName = @"";
    }
    
    // Update the editor's text with the code's description
    [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length])
                                      withString:keyName];
    
    // Resign first responder (closes the editor)
    [[self window] makeFirstResponder:(NSView *)self.delegate];
    
    return YES;
}

+ (NSString *)descriptionForKeyCode:(NSInteger)keyCode
{
	if (keyCode != AKKeyNone) {
        NSString *string = nil;
        if ((string = [keyCodeLookupTable objectForKey:@(keyCode)])) {
            return string;
        }
    }
	
    return @"";
}

+ (NSInteger)keyCodeForDescription:(NSString *)description
{
    if (description && [description length] > 0) {
        NSNumber *keyCode = [reverseKeyCodeLookupTable objectForKey:description];
        if (keyCode) {
            return [keyCode integerValue];
        }
    }
    
    return AKKeyNone;
}

- (BOOL)canUnmap
{
    return [[self string] length] > 0;
}

- (NSRect)unmapRect
{
    NSRect cellFrame = [self bounds];
    CGFloat diam = cellFrame.size.height * .70;
    return NSMakeRect(cellFrame.origin.x + cellFrame.size.width - cellFrame.size.height,
                      cellFrame.origin.y + (cellFrame.size.height - diam) / 2.0,
                      diam, diam);
}

#pragma mark - NSTextView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
    
    if ([self canUnmap]) {
        // Valid key
        
        NSRect circleRect = [self unmapRect];
        NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:circleRect];
        
        [[NSColor darkGrayColor] set];
        [path fill];
        
        NSRect dashRect = NSInsetRect(circleRect,
                                      circleRect.size.width * 0.2,
                                      circleRect.size.height * 0.6);
        
        path = [NSBezierPath bezierPathWithRect:dashRect];
        
        [[NSColor whiteColor] set];
        [path fill];
    } else {
        // No key
        
        NSBezierPath *bgRect = [NSBezierPath bezierPathWithRect:[self bounds]];
        
        [[NSColor controlBackgroundColor] set];
        [bgRect fill];
        
        NSMutableParagraphStyle *mpstyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mpstyle setAlignment:[self alignment]];
        
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    mpstyle, NSParagraphStyleAttributeName,
                                    [self font], NSFontAttributeName,
                                    [NSColor disabledControlTextColor], NSForegroundColorAttributeName,
                                    
                                    nil];
        
        [@"..." drawInRect:[self bounds] withAttributes:attributes];
    }
    
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
