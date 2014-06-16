//
//  AKAppDelegate.m
//  FinalBurn X
//
//  Created by Akop Karapetyan on 6/10/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "AKAppDelegate.h"

#import "AKEmulator.h"

@implementation AKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    AKEmulator *em = [[AKEmulator alloc] init];
    [em runROM:@"sfa3u"
         error:NULL];
}

@end
