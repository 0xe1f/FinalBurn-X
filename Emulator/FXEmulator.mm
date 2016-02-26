/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014-2016 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 **
 ******************************************************************************
 */
#import "FXEmulator.h"

#include "burner.h"

#import "FXInput.h"
#import "FXAudio.h"
#import "FXVideo.h"
#import "FXRunLoop.h"

#import "FXLoader.h" // FIXME

static FXEmulator *sharedInstance = nil;

@interface FXEmulator ()

- (void) initCore;
- (void) cleanupCore;

- (void) initPaths;

@end

@implementation FXEmulator

- (instancetype) initWithArchive:(NSString *) archive
{
	if (sharedInstance) {
		return sharedInstance;
	}
	
    if (self = [super init]) {
		sharedInstance = self;
		
		self->_archive = archive;
		
		[self setInput:[[FXInput alloc] init]];
		[self setAudio:[[FXAudio alloc] init]];
		[self setVideo:[[FXVideo alloc] init]];
		// FIXME
//		[self setRunLoop:[[FXRunLoop alloc] init]];
		
		[self initPaths];
		[self initCore];
    }
    
    return self;
}

- (void) dealloc
{
	[self cleanupCore];
}

#pragma mark - Static

+ (FXEmulator *) sharedInstance
{
	return sharedInstance;
}

#pragma mark - Core

- (void) initCore
{
	BurnLibInit();
}

- (void) cleanupCore
{
	BurnLibExit();
}

#pragma mark - Interaction

- (void) timerTick:(NSTimer *) aTimer
{
}

#pragma mark - Private

- (void) initPaths
{
	// FIXME
	self->_supportURL = [NSURL fileURLWithPath:@"/Users/akop/Library/Application Support/FinalBurn X"];
	
	[self setRomPath:[self->_supportURL URLByAppendingPathComponent:@"roms"]];
}

- (BOOL) start
{
	FXLoader *loader = [[FXLoader alloc] init];
	NSArray *array = [loader romSets];
	
	__block FXROMSet *selected = nil;
	[array enumerateObjectsUsingBlock:^(FXROMSet *rs, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([[rs archive] isEqualToString:self->_archive]) {
			selected = rs;
			*stop = YES;
		}
	}];
	
	if (!selected) {
		NSLog(@"Archive %@ not found", self->_archive);
		return NO;
	}
	
	NSString *auditCachePath = [[self->_supportURL URLByAppendingPathComponent:@"audits.cache"] path];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSDictionary *audits;
	if ([fm fileExistsAtPath:auditCachePath
				 isDirectory:nil]) {
		if ((audits = [NSKeyedUnarchiver unarchiveObjectWithFile:auditCachePath]) == nil) {
			NSLog(@"Error reading audit cache");
			return NO;
		}
	} else {
		NSLog(@"No audit file found");
		return NO;
	}

	[array enumerateObjectsUsingBlock:^(FXROMSet *romSet, NSUInteger idx, BOOL *stop) {
		FXDriverAudit *audit = [audits objectForKey:[romSet archive]];
		[romSet setAudit:audit];
		
		[[romSet subsets] enumerateObjectsUsingBlock:^(FXROMSet *subset, NSUInteger idx, BOOL *stop) {
			FXDriverAudit *subAudit = [audits objectForKey:[subset archive]];
			[subset setAudit:subAudit];
		}];
	}];
	
	NSLog(@"Loading: %@", [selected title]);

	// FIXME
//	[[self runLoop] setDelegate:self];
	
	[self setRunLoop:[[FXRunLoop alloc] initWithROMSet:selected]];
	[[self runLoop] start];
	
	return YES;
}

@end
