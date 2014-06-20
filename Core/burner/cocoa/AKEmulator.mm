//
//  AKEmulator.m
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/16/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import "AKEmulator.h"

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
	SDL_Init(SDL_INIT_TIMER|SDL_INIT_VIDEO|SDL_INIT_AUDIO);
    
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
    
	RunMessageLoop();
	InputExit();
    
	DrvExit();
	BurnLibExit();
	SDL_Quit();
    
	return YES;
}

- (void)dealloc
{
}

@end
