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
#import "FXImportOperation.h"

#import "FXZipArchive.h"

#pragma mark - FXImportItem

@interface FXImportItem : NSObject

@property (nonatomic, strong) NSString *archive;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) int distance;
@property (nonatomic, readonly) NSMutableArray<NSString *> *files;

@end

@implementation FXImportItem

- (instancetype) init
{
	if (self = [super init]) {
		self->_distance = INT_MAX;
		self->_files = [NSMutableArray array];
	}
	
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%i: %@: %@",
			self->_distance, self->_archive, self->_path];
}

@end

#pragma mark - FXImporter

@interface FXImportOperation ()

- (void) sort:(NSMutableArray<FXImportItem *> *) array;
- (void) import;
- (int) distanceToRoot:(NSDictionary *) set;

@end

@implementation FXImportOperation

- (void) main
{
	@try {
		[self import];
		if (![self isCancelled]) {
			[self->_delegate importDidComplete];
		}
	} @catch (NSException *e) {
		if (![self isCancelled]) {
			[self->_delegate importDidFail:[e reason]];
		}
	}
}

- (int) distanceToRoot:(NSDictionary *) set
{
	int distance = 0;
	NSDictionary *last = set;
	while (set) {
		last = set;
		set = [self->_setManifest objectForKey:[set objectForKey:@"parent"]];
		distance++;
	}
	
	if ([last objectForKey:@"bios"]) {
		distance++;
	}
	
	return distance;
}

- (void) sort:(NSMutableArray<FXImportItem *> *) array
{
	// Compute the distance of each item
	[array enumerateObjectsUsingBlock:^(FXImportItem *item, NSUInteger idx, BOOL * _Nonnull stop) {
		NSDictionary *set = [self->_setManifest objectForKey:[item archive]];
		[item setDistance:[self distanceToRoot:set]];
	}];
	
	// Sort by distance
	[array sortUsingComparator:^NSComparisonResult(FXImportItem *obj1, FXImportItem *obj2) {
		return [obj1 distance] - [obj2 distance];
	}];
}

- (void) import
{
	NSAssert(self->_setPath, @"Missing set path");
	NSAssert(self->_setManifest, @"Missing set manifest");
	NSAssert(self->_importPaths, @"Missing import paths");
	
	__block BOOL abortImport = NO;
	
	// Create an inheritance dictionary
	NSMutableDictionary <NSString *, NSMutableArray<NSString *> *> *children = [NSMutableDictionary dictionary];
	[self->_setManifest enumerateKeysAndObjectsUsingBlock:^(NSString *archive, NSDictionary *set, BOOL * _Nonnull stop) {
		if ([self isCancelled]) {
			*stop = abortImport = YES;
			return;
		}
		
		NSString *parent = [set objectForKey:@"parent"];
		if (parent) {
			NSMutableArray<NSString *> *array = [children objectForKey:parent];
			if (!array) {
				array = [NSMutableArray array];
				[children setObject:array
							 forKey:parent];
			}
			
			[array addObject:archive];
		}
	}];
	
	if (abortImport) {
		return;
	}
	
	// Go through file contents
//	[self->_importPaths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL * _Nonnull stop) {
//		if ([self isCancelled]) {
//			*stop = abortImport = YES;
//			return;
//		}
//		
//		NSError *error = nil;
//		FXZipArchive *fileArchive = [[FXZipArchive alloc] initWithPath:path
//																 error:&error];
//		
//		if (error) {
//			[self->_delegate importDidFail:[NSString stringWithFormat:NSLocalizedString(@"Error reading archive %@",
//																						@"Import error message"), path]];
//			*stop = abortImport = YES;
//			return;
//		}
//		
//		[[fileArchive files] enumerateObjectsUsingBlock:^(FXZipFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//			<#code#>
//		}];
//	}];
	
	if (abortImport) {
		return;
	}
	
	return;
	
	// Create importItems
	NSMutableSet<NSString *> *scheduledForImport = [NSMutableSet set];
	NSMutableArray<FXImportItem *> *importItems = [NSMutableArray array];
	
	[self->_importPaths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL * _Nonnull stop) {
		NSString *archive = [[path lastPathComponent] stringByDeletingPathExtension];
		NSDictionary *set = [self->_setManifest objectForKey:archive];
		if (set) {
			if (![scheduledForImport containsObject:archive]) {
				FXImportItem *item = [[FXImportItem alloc] init];
				[item setPath:path];
				[item setArchive:archive];
				
				[importItems addObject:item];
				[scheduledForImport addObject:archive];
			}
			
			NSMutableArray<NSString *> *subsets = [children objectForKey:archive];
			if (subsets) {
				[subsets enumerateObjectsUsingBlock:^(NSString *subarchive, NSUInteger idx, BOOL * _Nonnull stop) {
					if (![scheduledForImport containsObject:subarchive]) {
						FXImportItem *item = [[FXImportItem alloc] init];
						[item setPath:path];
						[item setArchive:subarchive];
						
						[importItems addObject:item];
						[scheduledForImport addObject:subarchive];
					}
				}];
			}
		}
	}];
	
	// Sort the items by inheritance
//	[self sort:importItems];
	
	// FIXME: etc
	
	NSLog(@"items: %@", importItems);
}

+ (BOOL) canImportPath:(NSString *) path
		   setManifest:(NSDictionary *) setManifest
{
	// Make sure it's a ZIP file
	if ([[path pathExtension] caseInsensitiveCompare:@"zip"] != NSOrderedSame) {
		return NO;
	}
	
	// Is it one of the supported archives?
	NSString *archive = [[path lastPathComponent] stringByDeletingPathExtension];
	return [setManifest objectForKey:archive] != nil;
}

@end
