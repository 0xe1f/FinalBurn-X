//
//  AKEmulator.m
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/16/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "AKEmulator.h"

#import "AKAppDelegate.h"
#import "FXEmulatorController.h"
#import "FXRunLoop.h"
#import "FXLoader.h"
#import "FXROMSetStatus.h"
#import "FXROMStatus.h"

#include "burner.h"

@interface AKEmulator()

- (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode;

@end

@implementation AKEmulator

- (instancetype)init
{
    if (self = [super init]) {
        
    }
    
    return self;
}

- (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode
{
    NSString *domain = @"org.akop.fbx.Emulation";
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
    
    return [NSError errorWithDomain:domain
                               code:errorCode
                           userInfo:userInfo];
}

- (BOOL)runROM:(NSString *)name
         error:(NSError **)error
{
	BurnLibInit();
    
    int driverId = [[FXLoader sharedLoader] driverIdForName:name];
    if (driverId < 0) {
        if (error != NULL) {
            *error = [self newErrorWithDescription:@"ROM set not recognized"
                                              code:ERROR_ROM_SET_UNRECOGNIZED];
        }
        return NO;
    }
    
    NSArray *romSetStatuses = [[FXLoader sharedLoader] scanROMSetIndex:driverId
                                                                 error:error];
    
    nBurnDrvActive = driverId;
    nBurnDrvSelect[0] = driverId;
    
    NSLog(@"%@ located at index %d", name, driverId);
    
	InputInit();
    
	bBurnUseASMCPUEmulation = 0;
 	bCheatsAllowed = false;
	DrvInit(driverId, 0);
    
    [romSetStatuses enumerateObjectsUsingBlock:^(id setStatus, NSUInteger idx, BOOL *stop) {
        if ([setStatus isArchiveFound]) {
            if ([setStatus isComplete]) {
                NSLog(@"++ rom set: %@ found in %@ and is complete", [setStatus archiveName], [setStatus path]);
            } else {
                NSLog(@"++ rom set: %@ found in %@, but is incomplete", [setStatus archiveName], [setStatus path]);
            }
        } else {
            NSLog(@"-- rom set: %@ (%ld) not found", [setStatus archiveName], idx);
        }
        
        [[setStatus ROMStatuses] enumerateObjectsUsingBlock:^(id status, NSUInteger idx, BOOL *stop) {
            NSLog(@"%@", [status message]);
        }];
    }];
    
    [[[[AKAppDelegate sharedInstance] emulator] runLoop] run];
    
	InputExit();
    
	DrvExit();
	BurnLibExit();
    
	return YES;
}

- (void)dealloc
{
}

@end
