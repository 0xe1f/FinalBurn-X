//
//  main.m
//  Emoolyator
//
//  Created by Akop Karapetyan on 2/25/16.
//  Copyright © 2016 Akop Karapetyan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#import "FXManifestBuilder.h"
#import "FXEmulator.h"

int main(int argc, const char * argv[])
{
	BOOL emulate = NO;
	BOOL dumpManifest = NO;
	
	if (argc == 2 && strncmp(argv[1], "-s", 2) == 0) {
		dumpManifest = YES;
	} else if (argc == 4) {
		emulate = YES;
	}
	
    @autoreleasepool {
		if (emulate) {
			NSString *archive = [NSString stringWithCString:argv[3]
												   encoding:NSUTF8StringEncoding];
			
			NSApplication *app = [NSApplication sharedApplication];
			FXEmulator *em = [[FXEmulator alloc] initWithArchive:archive];
			[app setDelegate:em];
			[em resumeConnection];
			
			[app run];
		} else if (dumpManifest) {
			FXManifestBuilder *builder = [[FXManifestBuilder alloc] init];
			NSDictionary *data = [builder romSets];
			
			[data writeToFile:@"/dev/stdout"
				   atomically:NO];
		} else {
			fprintf(stderr, "%s [-s|<ipc1> <ipc2> <romset>]\n", argv[0]);
			return 1;
		}
    }
	
    return 0;
}
