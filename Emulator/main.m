//
//  main.m
//  Emoolyator
//
//  Created by Akop Karapetyan on 2/25/16.
//  Copyright © 2016 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#import "FXEmulator.h"

int main(int argc, const char * argv[])
{
	if (argc < 4) {
		fprintf(stderr, "Missing required arguments\n");
		return 1;
	}
	
    @autoreleasepool {
		NSString *archive = [NSString stringWithCString:argv[3]
											   encoding:NSUTF8StringEncoding];
		
		NSApplication *app = [NSApplication sharedApplication];
		FXEmulator *em = [[FXEmulator alloc] initWithArchive:archive];
		[app setDelegate:em];
		[em resumeConnection];
		
		[app run];
    }
	
    return 0;
}
