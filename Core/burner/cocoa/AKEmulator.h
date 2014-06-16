//
//  AKEmulator.h
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/16/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKEmulator : NSObject

- (BOOL)runROM:(NSString *)name
         error:(NSError **)error;

#define ERROR_ROM_SET_UNRECOGNIZED -100

@end
