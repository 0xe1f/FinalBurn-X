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
#import "FXImporter.h"

#import "FXZipArchive.h"

#pragma mark - FXImportItem

@interface FXImportItem : NSObject

@property (nonatomic, strong) NSString *archive;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) NSInteger distance;

@end

@implementation FXImportItem

- (NSString *) description
{
	return self->_archive;
}

@end

#pragma mark - FXImporter

@interface FXImporter ()

- (void) sort;
- (void) import;

@end

@implementation FXImporter

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

- (void) sort:(NSMutableArray<FXImportItem *> *) array
{
}

- (void) import
{
	NSAssert(self->_setPath, @"Missing set path");
	NSAssert(self->_setManifest, @"Missing set manifest");
	NSAssert(self->_importPaths, @"Missing import paths");
	
	// Create importItems
	NSMutableArray<FXImportItem *> *importItems = [NSMutableArray array];
	[self->_importPaths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL * _Nonnull stop) {
		FXImportItem *item = [[FXImportItem alloc] init];
		[item setPath:path];
		[item setArchive:[[path lastPathComponent] stringByDeletingPathExtension]];
		
		[importItems addObject:item];
	}];
	
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
