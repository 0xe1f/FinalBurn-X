/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
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
#import "FXAboutController.h"

@implementation FXWhitePanelView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
}

@end

@implementation FXInvisibleScrollView

- (void) tile
{
    [[self contentView] setFrame:[self bounds]];
    [[self verticalScroller] setFrame:NSZeroRect];
}

@end

@implementation FXAboutController

- (id) init
{
    if ((self = [super initWithWindowNibName:@"About"]) != nil) {
    }

    return self;
}

- (void) awakeFromNib
{

}

- (void)dealloc
{
}

#pragma mark - NSWindowController

- (void) windowDidLoad
{
    [super windowDidLoad];

    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];

    [appNameField setStringValue:[infoDict objectForKey:@"CFBundleName"]];
    [versionNumberField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Version %@", @""),
                                      [infoDict objectForKey:@"CFBundleShortVersionString"]]];
}

#pragma mark - Actions

- (void) openFbaLicense:(id) sender
{
    NSString *documentPath = [[NSBundle mainBundle] pathForResource:@"FBALicense"
                                                             ofType:@"rtf"
                                                        inDirectory:@"Documents"];

    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:documentPath]];
}

- (void) openFbxLicense:(id) sender
{
    NSString *documentPath = [[NSBundle mainBundle] pathForResource:@"LICENSE"
                                                             ofType:@""
                                                        inDirectory:@"Documents"];

    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:documentPath]];
}

@end
