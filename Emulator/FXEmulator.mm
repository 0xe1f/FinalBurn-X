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

#import "OpenEmuXPCCommunicator/OpenEmuXPCCommunicator.h"
#import "FXEmulationCommunication.h"

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
- (BOOL) start;

@end

@implementation FXEmulator
{
	NSURL *_supportURL;
	NSXPCListener *_listener;
	NSXPCConnection *_mainAppConnection;
	int64_t _frameIndex;
}

- (instancetype) initWithArchive:(NSString *) archive
{
	if (sharedInstance) {
		return sharedInstance;
	}
	
    if (self = [super init]) {
		sharedInstance = self;
		
		self->_frameIndex = 0;
		self->_archive = archive;
		
		[self setInput:[[FXInput alloc] init]];
		[self setAudio:[[FXAudio alloc] init]];
		[self setVideo:[[FXVideo alloc] init]];
		[self setRunLoop:[[FXRunLoop alloc] init]];
		
		[self->_runLoop setDelegate:self];
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

#pragma mark - Private

- (void) initPaths
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSURL *appSupportUrl = [[fm URLsForDirectory:NSApplicationSupportDirectory
									   inDomains:NSUserDomainMask] lastObject];
	
	NSAssert(appSupportUrl != nil, @"App Support URL is null");
	
	self->_supportURL = [appSupportUrl URLByAppendingPathComponent:@"FinalBurn X"];
	
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
	
	[[self runLoop] setRomSet:selected];
	[[self runLoop] start];
	
	return YES;
}

#pragma mark - NSApplicationDelegate

- (void) applicationWillFinishLaunching:(NSNotification *) notification
{
	[self initPaths];
	[self initCore];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification
{
	[self start];
}

- (void) applicationWillTerminate:(NSNotification *) notification
{
	[[self runLoop] cancel];
}

#pragma mark - NSXPCListenerDelegate

- (BOOL) listener:(NSXPCListener *) listener
shouldAcceptNewConnection:(NSXPCConnection *) newConnection
{
	self->_mainAppConnection = newConnection;
	[self->_mainAppConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(FXEmulationCommunication)]];
	[self->_mainAppConnection setExportedObject:self];
	[self->_mainAppConnection resume];
	
	return YES;
}

#pragma mark - FXEmulationCommunication

- (oneway void) updateInput:(FXInputState *) state
{
	[self->_input updateState:state];
}

- (void) describeScreenWithHandler:(void (^)(BOOL, NSInteger)) handler
{
	handler([self->_video ready], [self->_video surfaceId]);
}

- (void) renderScreenWithHandler:(void (^)(NSData *, NSInteger)) handler
{
	int64_t frame = OSAtomicIncrement64(&self->_frameIndex);
	handler(nil, frame);
}

#pragma mark - Other XPC

- (void) resumeConnection
{
	self->_listener = [NSXPCListener anonymousListener];
	[self->_listener setDelegate:self];
	[self->_listener resume];
	
	NSXPCListenerEndpoint *endpoint = [self->_listener endpoint];
	[[OEXPCCAgent defaultAgent] registerListenerEndpoint:endpoint
										   forIdentifier:[OEXPCCAgent defaultProcessIdentifier]
									   completionHandler:^(BOOL success)
	{
		NSLog(@"Connection successful!");
	}];
}

@end
