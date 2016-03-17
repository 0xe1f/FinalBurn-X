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
#include "driverlist.h"
#include "burnint.h"

#import "FXInput.h"
#import "FXAudio.h"
#import "FXVideo.h"
#import "FXRunLoop.h"

#import "FXInputMap.h"
#import "FXZipArchive.h"
#import "FXEmulationState.h"

static FXEmulator *sharedInstance = nil;

static int cocoaLoadROMCallback(unsigned char *Dest, INT32 *pnWrote, int i);

@interface FXEmulator ()

- (void) initCore;
- (void) cleanupCore;

- (void) initPaths;
- (BOOL) start;

- (UInt32) loadROMIndex:(int) romIndex
			 intoBuffer:(void *) buffer
		   bufferLength:(INT32 *) length;

- (FXEmulationState *) currentState;

@end

@implementation FXEmulator
{
	BOOL _loadComplete;
	NSString *_supportPath;
	NSXPCListener *_listener;
	NSXPCConnection *_mainAppConnection;
	NSDictionary *_setAudit;
	NSMutableDictionary<NSString *, FXZipArchive *> *_fileCache;
}

- (instancetype) initWithArchive:(NSString *) archive
{
	if (sharedInstance) {
		return sharedInstance;
	}
	
    if (self = [super init]) {
		sharedInstance = self;
		
		self->_archive = archive;
		
		self->_input = [[FXInput alloc] init];
		self->_audio = [[FXAudio alloc] init];
		self->_video = [[FXVideo alloc] init];
		self->_runLoop = [[FXRunLoop alloc] init];
		
		[self->_runLoop setDelegate:self];
		self->_fileCache = [NSMutableDictionary dictionary];
		
		[AKKeyboardManager sharedInstance];
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

- (FXEmulationState *) currentState
{
	FXEmulationState *current = [[FXEmulationState alloc] init];
	[current setIsRunning:self->_loadComplete];
	[current setIsPaused:[self->_runLoop isPaused]];
	
	return current;
}

- (void) initPaths
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString *appSupportRoot = [[[fm URLsForDirectory:NSApplicationSupportDirectory
											inDomains:NSUserDomainMask] lastObject] path];
	
	NSAssert(appSupportRoot != nil, @"App Support URL is null");
	
	self->_supportPath = [appSupportRoot stringByAppendingPathComponent:@"FinalBurn X"];
	self->_romPath = [self->_supportPath stringByAppendingPathComponent:@"roms"];
}

- (BOOL) start
{
#if DEBUG
	NSDate *started = [NSDate date];
#endif
	NSString *auditCachePath = [self->_supportPath stringByAppendingPathComponent:@"audit.cache"];
	NSDictionary *auditData = [NSDictionary dictionaryWithContentsOfFile:auditCachePath];
#ifdef DEBUG
	NSLog(@"Loaded audit cache (%.04fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
	
	if (!auditData) {
		NSLog(@"Error reading audit cache");
		return NO;
	}
	
	self->_setAudit = [auditData objectForKey:self->_archive];
	if (!self->_setAudit || [self->_setAudit objectForKey:@"status"] == 0) {
		NSLog(@"Set %@ is incomplete or unplayable", self->_archive);
		return NO;
	}
	
	nBurnDrvActive = -1;
	const char *cArchive = [self->_archive cStringUsingEncoding:NSASCIIStringEncoding];
	for (int i = 0; i < nBurnDrvCount; i++) {
		if (strcasecmp(pDriver[i]->szShortName, cArchive) == 0) {
			nBurnDrvActive = i;
			nBurnDrvSelect[0] = i;
			break;
		}
	}
	
	if (nBurnDrvActive == -1) {
		NSLog(@"Driver index not found");
		return NO;
	}
	
	BurnExtLoadRom = cocoaLoadROMCallback;
	
	[self->_runLoop start];
	
	return YES;
}

#pragma mark - FXRunLoopDelegate

- (void) loadingDidStart
{
#if DEBUG
	NSLog(@"Emulator/loadingDidStart");
#endif
}

- (void) loadingDidEnd
{
#if DEBUG
	NSLog(@"Emulator/loadingDidEnd");
#endif
	[self->_fileCache removeAllObjects];
	self->_loadComplete = YES;
}

#pragma mark - NSApplicationDelegate

- (void) applicationWillFinishLaunching:(NSNotification *) notification
{
	[self initPaths];
	[self initCore];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification
{
	if (![self start]) {
		[[NSApplication sharedApplication] terminate:self];
	}
}

- (void) applicationWillTerminate:(NSNotification *) notification
{
	if ([self->_runLoop isExecuting]) {
		[self->_runLoop cancel];
	}
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

- (void) updateStateWithHandler:(void(^)(FXEmulationState *current)) handler
{
	handler([self currentState]);
}

- (void) setPaused:(BOOL) paused
	   withHandler:(void (^)(FXEmulationState *)) handler
{
	[self->_runLoop setPaused:paused];
	handler([self currentState]);
}

- (void) resetEmulationWithHandler:(void(^)(FXEmulationState *current)) handler
{
	[self->_input reset];
	handler([self currentState]);
}

- (void) enterDiagnostics
{
	[self->_input startDiagnostics];
}

- (void) startTrackingInputWithMap:(FXInputMap *) map
{
	[self->_input startTrackingInputWithMap:map];
}

- (void) stopTrackingInput
{
	[self->_input stopTrackingInput];
}

- (void) describeScreenWithHandler:(void (^)(NSInteger)) handler
{
	handler([self->_video surfaceId]);
}

- (void) shutDown
{
	[[NSApplication sharedApplication] terminate:self];
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

#pragma mark - Private

- (UInt32) loadROMIndex:(int) romIndex
			 intoBuffer:(void *) buffer
		   bufferLength:(INT32 *) length
{
	struct BurnRomInfo info;
	if (pDriver[nBurnDrvActive]->GetRomInfo(&info, romIndex)) {
		return 1;
	}
	
	char *cAlias = NULL;
	if (pDriver[nBurnDrvActive]->GetRomName(&cAlias, romIndex, 0) != 0) {
		return 1;
	}
	
	NSString *filename = [NSString stringWithCString:cAlias
											encoding:NSASCIIStringEncoding];
	
	NSString *location = [[[self->_setAudit objectForKey:@"files"] objectForKey:filename] objectForKey:@"location"];
	if (!location) {
		NSLog(@"Not found: %@", filename);
		return 1;
	}
	
	FXZipArchive *archive = [self->_fileCache objectForKey:location];
	if (!archive) {
		NSError *error = nil;
		archive = [[FXZipArchive alloc] initWithPath:[self->_romPath stringByAppendingPathComponent:location]
											   error:&error];
		if (error) {
			NSLog(@"Error reading %@: %@", location, [error description]);
			return 1;
		}
		
		[self->_fileCache setObject:archive
							 forKey:location];
	}
	
	FXZipFile *file = [archive findFileNamed:filename
							  matchExactPath:NO];
	if (!file) {
		NSLog(@"File %@ not found in %@", filename, location);
		return 1;
	}
	
	NSError *error = nil;
	NSData *content = [file readContentWithError:&error];
	if (error) {
		NSLog(@"Error reading %@ in %@: %@",
			  filename, location, [error description]);
		return 1;
	}
	
	[content getBytes:buffer
			   length:info.nLen];
	
	if (length) {
		*length = info.nLen;
	}
	
#ifdef DEBUG
	NSLog(@"Read %@ (%@kB) from %@", filename,
		  [@(info.nLen / 1024) descriptionWithLocale:[NSLocale currentLocale]],
		  location);
#endif
	
	return 0;
}

@end

#pragma mark - FB Callbacks

static int cocoaLoadROMCallback(unsigned char *Dest, INT32 *pnWrote, int i)
{
	FXEmulator *e = [FXEmulator sharedInstance];
	return [e loadROMIndex:i
				intoBuffer:Dest
			  bufferLength:pnWrote];
}
