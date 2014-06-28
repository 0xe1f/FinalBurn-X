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
    
    const char *romName = [name UTF8String];
    
    int romIndex = -1;
    for (int i = 0; i < nBurnDrvCount; i++) {
        nBurnDrvActive = i;
        nBurnDrvSelect[0] = i;
        
        if (strcmp(BurnDrvGetTextA(DRV_NAME), romName) == 0) {
            romIndex = i;
            break;
        }
    }
    
    if (romIndex < 0) {
        if (error != NULL) {
            *error = [self newErrorWithDescription:@"ROM set not recognized"
                                              code:ERROR_ROM_SET_UNRECOGNIZED];
        }
        return NO;
    }

    NSLog(@"%@ located at index %d", name, romIndex);
    
	InputInit();
    
	bBurnUseASMCPUEmulation = 0;
 	bCheatsAllowed = false;
	DrvInit(romIndex, 0);
    
    FXLoader *loader = [[FXLoader alloc] init];
    
    NSArray *romSetStatuses = [loader scanROMSetIndex:romIndex
                                                error:(NSError **)error];
    
    [romSetStatuses enumerateObjectsUsingBlock:^(id setStatus, NSUInteger idx, BOOL *stop) {
        if ([setStatus isArchiveFound]) {
            if ([setStatus isComplete]) {
                NSLog(@"++ rom set: %@ found in %@ and is complete", [setStatus archiveName], [setStatus path]);
            } else {
                NSLog(@"++ rom set: %@ found in %@, but is incomplete", [setStatus archiveName], [setStatus path]);
            }
        } else {
            NSLog(@"-- rom set: %@ not found", [setStatus archiveName]);
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
