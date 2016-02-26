//
//  main.m
//  Emoolyator
//
//  Created by Akop Karapetyan on 2/25/16.
//  Copyright © 2016 Akop Karapetyan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FXEmulator.h"

int main(int argc, const char * argv[])
{
	if (argc < 2) {
		fprintf(stderr, "Which archive?\n");
		return 1;
	}
	
    @autoreleasepool {
		NSString *archive = [NSString stringWithCString:argv[1]
											   encoding:NSUTF8StringEncoding];
		
		FXEmulator *em = [[FXEmulator alloc] initWithArchive:archive];
		BOOL started = [em start];
		
		if (started) {
			[NSTimer scheduledTimerWithTimeInterval:0.5
											 target:em
										   selector:@selector(timerTick:)
										   userInfo:nil
											repeats:YES];
			
			[[NSRunLoop currentRunLoop] run];
		} else {
			NSLog(@"Couldn't start");
			return 1;
		}
    }
	
    return 0;
}
