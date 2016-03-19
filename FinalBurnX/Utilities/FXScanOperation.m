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
#import "FXScanOperation.h"

#import "FXZipArchive.h"

NSString *const kFXSetStatus = @"status";
NSString *const kFXSetFiles = @"files";
NSString *const kFXFileStatus = @"status";
NSString *const kFXFileLocation = @"location";
NSString *const kFXErrorMessage = @"errorMessage";

#pragma mark - FXSetItem

@interface FXSetItem : NSObject

@property (nonatomic, assign) BOOL isRequired;
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
@property (nonatomic, weak) FXSet *bios;
@property (nonatomic, readonly) NSMutableDictionary<NSNumber *, FXSetItem *> *files;
@property (nonatomic, assign) NSInteger missingFileCount;

- (NSInteger) status;

@end

@implementation FXSet

- (instancetype) initWithArchive:(NSString *) archive
{
	if (self = [super init]) {
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

#pragma mark - FXScanner

@interface FXScanOperation()

- (void) startScan;
- (void) scanFileArchive:(FXZipArchive *) fileArchive;
- (NSDictionary *) resultsAsPlist;

@end

@implementation FXScanOperation
{
	NSMutableDictionary<NSString *, FXSet *> *_results;
}

- (instancetype) init
{
	if (self = [super init]) {
		self->_results = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void) main
{
	@try {
		[self startScan];
		if (![self isCancelled]) {
			[self->_delegate scanDidComplete:[self resultsAsPlist]];
		}
	} @catch (NSException *e) {
		[self->_delegate scanDidFail:[e reason]];
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

- (void) startScan
{
#ifdef DEBUG
	NSDate *started = [NSDate date];
#endif
	
	[self->_results removeAllObjects];
	[self->_setManifest enumerateKeysAndObjectsUsingBlock:^(NSString *archiveName, NSDictionary *values, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		__block int requiredCount = 0;
		
		FXSet *set = [[FXSet alloc] initWithArchive:archiveName];
		[self->_results setObject:set
						   forKey:archiveName];
		
		// Add unique files needed by the set
		[[[values objectForKey:@"files"] objectForKey:@"local"] enumerateKeysAndObjectsUsingBlock:^(NSString *filename, NSDictionary *fileValues, BOOL * _Nonnull stop) {
			if ([self isCancelled]) {
				*stop = YES;
				return;
			}
			
			FXSetItem *item = [[FXSetItem alloc] initWithFilename:filename];
			if (![[fileValues objectForKey:@"attrs"] containsString:@"optional"]) {
				requiredCount++;
				[item setIsRequired:YES];
			}
			
			[[set files] setObject:item
							forKey:[fileValues objectForKey:@"crc"]];
		}];
		
		// Add files that are part of the superset
		NSDictionary *parentSet = [self->_setManifest objectForKey:[values objectForKey:@"parent"]];
		if (parentSet) {
			NSDictionary *parentFiles = [[parentSet objectForKey:@"files"] objectForKey:@"local"];
			[[[values objectForKey:@"files"] objectForKey:@"parent"] enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL * _Nonnull stop) {
				if ([self isCancelled]) {
					*stop = YES;
					return;
				}
				
				FXSetItem *item = [[FXSetItem alloc] initWithFilename:filename];
				NSDictionary *parentFile = [parentFiles objectForKey:filename];
				if (![[parentFile objectForKey:@"attrs"] containsString:@"optional"]) {
					requiredCount++;
					[item setIsRequired:YES];
				}
				
				[[set files] setObject:item
								forKey:[parentFile objectForKey:@"crc"]];
			}];
		}
		
		// Add files that are part of the bios set
		NSDictionary *biosSet = [self->_setManifest objectForKey:[values objectForKey:@"bios"]];
		if (biosSet) {
			NSDictionary *biosFiles = [[biosSet objectForKey:@"files"] objectForKey:@"local"];
			[[[values objectForKey:@"files"] objectForKey:@"bios"] enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL * _Nonnull stop) {
				if ([self isCancelled]) {
					*stop = YES;
					return;
				}
				
				FXSetItem *item = [[FXSetItem alloc] initWithFilename:filename];
				NSDictionary *biosFile = [biosFiles objectForKey:filename];
				if (![[biosFile objectForKey:@"attrs"] containsString:@"optional"]) {
					requiredCount++;
					[item setIsRequired:YES];
				}
				
				[[set files] setObject:item
								forKey:[biosFile objectForKey:@"crc"]];
			}];
		}
		
		// Initialize missing file count
		[set setMissingFileCount:requiredCount];
	}];
	
	// Initialize hierarchy
	[self->_setManifest enumerateKeysAndObjectsUsingBlock:^(NSString *archiveName, NSDictionary *values, BOOL * _Nonnull stop) {
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
		FXSet *bios = [self->_results objectForKey:[values objectForKey:@"bios"]];
		if (bios) {
			[set setBios:bios];
			[[bios children] addObject:set];
		}
	}];
	
	__autoreleasing NSError *error = nil;
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self->_rootPath
																		 error:&error];
	[files enumerateObjectsUsingBlock:^(NSString *file, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = YES;
			return;
		}
		
		__autoreleasing NSError *blockErr = nil;
		if ([[file pathExtension] caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
			NSString *fullPath = [self->_rootPath stringByAppendingPathComponent:file];
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
			if ([item isRequired]) {
				[set setMissingFileCount:[set missingFileCount] - 1];
			}
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
				if ([subitem isRequired]) {
					[subset setMissingFileCount:[subset missingFileCount] - 1];
				}
				[subitem setLocation:archiveFilename];
				[subitem setStatus:FXFileStatusValid];
			}
		}];
	}];
}

@end
