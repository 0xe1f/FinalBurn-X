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
#import "FXScanner.h"

#import "FXZipArchive.h"

NSString *const kFXSetStatus = @"status";
NSString *const kFXSetFiles = @"files";
NSString *const kFXFileStatus = @"status";
NSString *const kFXFileLocation = @"location";
NSString *const kFXErrorMessage = @"errorMessage";

#pragma mark - FXSetItem

@interface FXSetItem : NSObject

@property (nonatomic, strong) NSString *filename;
@property (nonatomic, strong) NSString *location;
@property (nonatomic, assign) NSInteger status;

@end

@implementation FXSetItem

- (instancetype) initWithFilename:(NSString *) filename
{
	if (self = [super init]) {
		self->_filename = filename;
		self->_location = nil;
		self->_status = FXFileStatusMissing;
	}
	
	return self;
}

@end

#pragma mark - FXSet

@class FXSet;

@interface FXSet : NSObject

@property (nonatomic, strong) NSString *archive;
@property (nonatomic, readonly) NSMutableArray<FXSet *> *children;
@property (nonatomic, weak) FXSet *parent;
@property (nonatomic, readonly) NSMutableDictionary<NSNumber *, FXSetItem *> *files;
@property (nonatomic, assign) NSInteger missingFileCount;

- (NSInteger) status;

@end

@implementation FXSet

- (instancetype) initWithArchive:(NSString *) archive
{
	if (self = [super init]) {
		self->_parent = nil;
		self->_archive = archive;
		self->_children = [NSMutableArray array];
		self->_files = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (NSInteger) status
{
	return self->_missingFileCount == 0 ? FXSetStatusComplete : FXSetStatusIncomplete;
}

@end

#pragma mark - FXScanOperation

@interface FXScanOperation : NSOperation

- (instancetype) initWithScanner:(FXScanner *) scanner;

// Private
- (void) scan;
- (void) scanFileArchive:(FXZipArchive *) fileArchive;
- (NSDictionary *) resultsAsPlist;

@end

@implementation FXScanOperation
{
	NSMutableDictionary<NSString *, FXSet *> *_results;
	FXScanner *_scanner;
}

- (instancetype) initWithScanner:(FXScanner *) scanner
{
	if (self = [super init]) {
		self->_scanner = scanner;
		self->_results = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void) main
{
	@try {
		[self scan];
		if (![self isCancelled]) {
			[[self->_scanner delegate] scanDidComplete:[self resultsAsPlist]];
		}
	} @catch (NSException *e) {
		[[self->_scanner delegate] scanDidFail:@{ kFXErrorMessage: [e reason] }];
	}
}

- (NSDictionary *) resultsAsPlist
{
	NSMutableDictionary *plist = [NSMutableDictionary dictionary];
	[self->_results enumerateKeysAndObjectsUsingBlock:^(NSString *archive, FXSet *set, BOOL * _Nonnull stop) {
		NSMutableDictionary<NSString *, NSDictionary *> *setFiles = [NSMutableDictionary dictionary];
		[[set files] enumerateKeysAndObjectsUsingBlock:^(NSNumber *crc, FXSetItem *item, BOOL * _Nonnull stop) {
			if ([item location]) {
				[setFiles setObject:@{ kFXFileLocation: [item location],
									   kFXFileStatus: @([item status]), }
							 forKey:[item filename]];
			}
		}];
		
		if ([setFiles count] > 0) {
			[plist setObject:@{ kFXSetFiles: setFiles,
								kFXSetStatus: @([set status]), }
					  forKey:archive];
		}
	}];
	
	return plist;
}

- (void) scan
{
#ifdef DEBUG
	NSDate *started = [NSDate date];
#endif
	
	NSDictionary *sm = [self->_scanner sets];
	NSString *rootPath = [self->_scanner rootPath];
	
	[self->_results removeAllObjects];
	[sm enumerateKeysAndObjectsUsingBlock:^(NSString *archiveName, NSDictionary *values, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		FXSet *set = [[FXSet alloc] initWithArchive:archiveName];
		[self->_results setObject:set
						   forKey:archiveName];
		
		// Add unique files needed by the set
		[[[values objectForKey:@"files"] objectForKey:@"local"] enumerateKeysAndObjectsUsingBlock:^(NSString *filename, NSDictionary *fileValues, BOOL * _Nonnull stop) {
			if ([self isCancelled]) {
				*stop = YES;
				return;
			}
			[[set files] setObject:[[FXSetItem alloc] initWithFilename:filename]
							forKey:[fileValues objectForKey:@"crc"]];
		}];
		
		// Add files that are part of the superset
		NSDictionary *parentSet = [sm objectForKey:[values objectForKey:@"parent"]];
		if (parentSet) {
			NSDictionary *parentFiles = [[parentSet objectForKey:@"files"] objectForKey:@"local"];
			[[[values objectForKey:@"files"] objectForKey:@"super"] enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL * _Nonnull stop) {
				if ([self isCancelled]) {
					*stop = YES;
					return;
				}
				[[set files] setObject:[[FXSetItem alloc] initWithFilename:filename]
								forKey:[[parentFiles objectForKey:filename] objectForKey:@"crc"]];
			}];
		}
		
		// Initialize missing file count
		[set setMissingFileCount:[[set files] count]];
	}];
	
	// Initialize hierarchy
	[sm enumerateKeysAndObjectsUsingBlock:^(NSString *archiveName, NSDictionary *values, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		FXSet *set = [self->_results objectForKey:archiveName];
		FXSet *parent = [self->_results objectForKey:[values objectForKey:@"parent"]];
		if (parent) {
			[set setParent:parent];
			[[parent children] addObject:set];
		}
	}];
	
	__autoreleasing NSError *error = nil;
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootPath
																		 error:&error];
	[files enumerateObjectsUsingBlock:^(NSString *file, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		__autoreleasing NSError *blockErr = nil;
		if ([[file pathExtension] caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
			NSString *fullPath = [rootPath stringByAppendingPathComponent:file];
			FXZipArchive *fileArchive = [[FXZipArchive alloc] initWithPath:fullPath
																	 error:&blockErr];
			if (!blockErr) {
				[self scanFileArchive:fileArchive];
			}
		}
	}];
#ifdef DEBUG
	NSLog(@"Completed scan (%.02fs)", [[NSDate date] timeIntervalSinceDate:started]);
#endif
}

- (void) scanFileArchive:(FXZipArchive *) fileArchive
{
	NSString *archiveFilename = [[fileArchive path] lastPathComponent];
	FXSet *set = [self->_results objectForKey:[archiveFilename stringByDeletingPathExtension]];
	
	[[fileArchive files] enumerateObjectsUsingBlock:^(FXZipFile *file, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		FXSetItem *item = [[set files] objectForKey:@([file crc])];
		if (item && ![item location]) {
			[set setMissingFileCount:[set missingFileCount] - 1];
			[item setLocation:archiveFilename];
			[item setStatus:FXFileStatusValid];
		}
		[[set children] enumerateObjectsUsingBlock:^(FXSet *subset, NSUInteger idx, BOOL * _Nonnull stop) {
			if ([self isCancelled]) {
				*stop = YES;
				return;
			}
			
			FXSetItem *subitem = [[subset files] objectForKey:@([file crc])];
			if (subitem && ![subitem location]) {
				[subset setMissingFileCount:[subset missingFileCount] - 1];
				[subitem setLocation:archiveFilename];
				[subitem setStatus:FXFileStatusValid];
			}
		}];
	}];
}

@end

#pragma mark - FXScanner

@implementation FXScanner
{
	NSOperationQueue *_opQueue;
	NSObject *_lock;
}

- (instancetype) init
{
	if (self = [super init]) {
		self->_opQueue = [[NSOperationQueue alloc] init];
		self->_lock = [[NSObject alloc] init];
	}
	
	return self;
}

#pragma mark - Public

- (void) start
{
	@synchronized(self->_opQueue) {
		if ([self->_opQueue operationCount] < 1) {
			FXScanOperation *op = [[FXScanOperation alloc] initWithScanner:self];
			[self->_opQueue addOperation:op];
		}
	}
}

- (void) stopAll
{
	[self->_opQueue cancelAllOperations];
	[self->_opQueue waitUntilAllOperationsAreFinished];
}

@end
