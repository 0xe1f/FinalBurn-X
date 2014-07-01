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
#import "FXDriverAudit.h"

#include "burner.h"

@interface AKEmulator()

- (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode;
- (BOOL)initializeDriver:(int)driverId
                   error:(NSError **)error;
- (BOOL)cleanupDriver;

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

- (BOOL)initializeDriver:(int)driverId
                   error:(NSError **)error
{
    [self cleanupDriver];

#ifdef DEBUG
    NSLog(@"Initializing driver...");
#endif

	AudSoundInit();
    
    nBurnDrvActive = driverId;
	nBurnDrvSelect[0] = driverId;
    
	nMaxPlayers = BurnDrvGetMaxPlayers();
	GameInpInit();
    
	ConfigGameLoad(true);
	InputMake(true);
    
	GameInpDefault();
    
    BurnExtLoadRom = cocoaLoadROMCallback;
    
	if (BurnDrvInit()) {
        if (error != NULL) {
            *error = [self newErrorWithDescription:@"Error initializing core driver"
                                              code:FXErrorInitializingCoreDriver];
        }
        
		BurnDrvExit();
        return NO;
	}
    
	bDrvOkay = 1;
	nBurnLayer = 0xFF;
    
    return YES;
}

- (BOOL)cleanupDriver
{
	if (bDrvOkay) {
		VidExit();
        AudSoundExit();
        
		if (nBurnDrvSelect[0] < nBurnDrvCount) {
			ConfigGameSave(bSaveInputs);
            
			GameInpExit();				// Exit game input
			BurnDrvExit();				// Exit the driver
		}
	}
    
	BurnExtLoadRom = NULL;
    
	bDrvOkay = 0;					// Stop using the BurnDrv functions
    
	if (bAudOkay) {
        // Write silence into the sound buffer
		memset(nAudNextSound, 0, nAudSegLen << 2);
	}
    
	nBurnDrvSelect[0] = ~0U;			// no driver selected
    
#ifdef DEBUG
    NSLog(@"Driver cleaned up");
#endif
    
	return YES;
}

- (BOOL)runROM:(NSString *)name
         error:(NSError **)error
{
	BurnLibInit();
    
    int driverId = [[FXLoader sharedLoader] driverIdForName:name];
    if (driverId < 0) {
        if (error != NULL) {
            *error = [self newErrorWithDescription:@"ROM set not recognized"
                                              code:FXErrorROMSetUnrecognized];
        }
        return NO;
    }
    
    FXDriverAudit *driverAudit = [[FXLoader sharedLoader] auditDriver:driverId
                                                                error:error];
    
    NSLog(@"%@ located at index %d", name, driverId);
    
	InputInit();
    
	bBurnUseASMCPUEmulation = 0;
 	bCheatsAllowed = false;
    
    if (![self initializeDriver:driverId
                          error:error]) {
        return NO;
    }
    
    if ([driverAudit isPerfect]) {
        NSLog(@"++ rom set: %@ found and is perfect", [driverAudit archiveName]);
    } else {
        NSLog(@"++ rom set: %@ found, but is incomplete", [driverAudit archiveName]);
    }
    
    [[driverAudit ROMAudits] enumerateObjectsUsingBlock:^(FXROMAudit *romAudit, NSUInteger idx, BOOL *stop) {
        NSLog(@"%@", [romAudit message]);
    }];
    
    [[[[AKAppDelegate sharedInstance] emulator] runLoop] run];
    
	InputExit();
    
    [self cleanupDriver];
	BurnLibExit();
    
	return YES;
}

- (void)dealloc
{
}

@end
