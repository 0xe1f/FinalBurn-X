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
#import "FXZipArchive.h"

#pragma mark - Interfaces

@interface FXZipArchive ()

- (BOOL) locateFileWithCRC:(NSUInteger) crc
					 error:(NSError **) error;
- (NSData *) readFileContent:(FXZipFile *) file
					   error:(NSError *__autoreleasing *) error;

- (void) invalidateTOC;
- (void) validateTOC;

@end

#pragma mark - FXZipFile

@implementation FXZipFile
{
	__weak FXZipArchive *_owner;
}

- (instancetype) initWithOwner:(FXZipArchive *) owner
{
	if (self = [super init]) {
		self->_owner = owner;
	}
	
	return self;
}

- (NSData *) readContentWithError:(NSError *__autoreleasing *) error
{
	return [self->_owner readFileContent:self
								   error:error];
}

@end

#pragma mark - FXZipArchive

@implementation FXZipArchive
{
	unzFile _zipFile;
	NSArray<FXZipFile *> *_toc;
}

- (instancetype) initWithPath:(NSString *) path
						error:(NSError **) error
{
	if (self = [super init]) {
		const char *cpath = [path cStringUsingEncoding:NSUTF8StringEncoding];
		self->_zipFile = unzOpen(cpath);
		if (self->_zipFile != NULL) {
			self->_path = path;
		} else {
			if (error != NULL) {
				*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
											 code:FXErrorLoadingArchive
										 userInfo:@{ NSLocalizedDescriptionKey: @"Error loading archive" }];
			}
		}
	}
	
	return self;
}

- (void) dealloc
{
	if (self->_zipFile != NULL) {
		unzClose(self->_zipFile);
		self->_zipFile = NULL;
	}
}

#pragma mark - Public

- (FXZipFile *) findFileWithCRC:(NSUInteger) crc
{
	__block FXZipFile *matching = nil;
	[[self files] enumerateObjectsUsingBlock:^(FXZipFile *file, NSUInteger idx, BOOL *stop) {
		if ([file crc] == crc) {
			matching = file;
			*stop = YES;
		}
	}];
	
	return matching;
}

- (FXZipFile *) findFileNamed:(NSString *) filename
			   matchExactPath:(BOOL) exactPath
{
	__block FXZipFile *matching = nil;
	[[self files] enumerateObjectsUsingBlock:^(FXZipFile *file, NSUInteger idx, BOOL *stop) {
		NSString *path = [file filename];
		if (!exactPath) {
			path = [path lastPathComponent];
		}
		
		if ([path caseInsensitiveCompare:filename] == NSOrderedSame) {
			matching = file;
			*stop = YES;
		}
	}];
	
	return matching;
}

- (FXZipFile *) findFileNamedAnyOf:(NSArray *) filenames
					matchExactPath:(BOOL) exactPath
{
	__block FXZipFile *matching = nil;
	[filenames enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL *stop) {
		FXZipFile *file = [self findFileNamed:filename
							   matchExactPath:exactPath];
		if (file != nil) {
			matching = file;
			*stop = YES;
		}
	}];
	
	return matching;
}

- (NSUInteger) fileCount
{
	NSUInteger count = 0;
	
	if (self->_zipFile != NULL) {
		unz_global_info globalInfo;
		unzGetGlobalInfo(self->_zipFile, &globalInfo);
		count = globalInfo.number_entry;
	}
	
	return count;
}

- (NSArray *) files
{
	[self validateTOC];
	return [NSArray arrayWithArray:self->_toc];
}

#pragma mark - Private

- (void) validateTOC
{
	if (self->_toc) {
		return;
	}
	
	const int len = 1024;
	char temp[len];
	
	NSMutableArray<FXZipFile *> *toc = [NSMutableArray array];
	if (self->_zipFile != NULL) {
		NSUInteger n = [self fileCount];
		for (int i = 0, rv = unzGoToFirstFile(self->_zipFile);
			 i < n && rv == UNZ_OK;
			 i++, rv = unzGoToNextFile(self->_zipFile)) {
			// Get individual file record
			unz_file_info fileInfo;
			if (unzGetCurrentFileInfo(self->_zipFile, &fileInfo, temp, len, NULL, 0, NULL, 0) != UNZ_OK) {
				continue;
			}
			
			FXZipFile *file = [[FXZipFile alloc] initWithOwner:self];
			[file setFilename:[NSString stringWithCString:temp
												 encoding:NSUTF8StringEncoding]];
			[file setCrc:(UInt32) fileInfo.crc];
			[file setLength:fileInfo.uncompressed_size];
			
			[toc addObject:file];
		}
	}
	
	self->_toc = toc;
}

- (void) invalidateTOC
{
	self->_toc = nil;
}

- (NSData *) readFileContent:(FXZipFile *) file
					   error:(NSError *__autoreleasing *) error
{
	NSInteger bytesRead = -1;
	NSError *localError = NULL;
	
	if (![self locateFileWithCRC:[file crc]
						   error:&localError]) {
		if (error != NULL && localError != NULL) {
			*error = localError;
		}
		
		return nil;
	}
	
	int rv = unzOpenCurrentFile(self->_zipFile);
	if (rv != UNZ_OK) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
										 code:FXErrorOpeningCompressedFile
									 userInfo:@{ NSLocalizedDescriptionKey : @"Error opening compressed file" }];
		}
		
		return nil;
	}
	
	NSMutableData *data = [[NSMutableData alloc] initWithLength:[file length]];
	rv = unzReadCurrentFile(self->_zipFile,
							[data mutableBytes], (unsigned int) [file length]);
	if (rv < 0) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
										 code:FXErrorReadingCompressedFile
									 userInfo:@{ NSLocalizedDescriptionKey : @"Error reading compressed file" }];
		}
		
		return nil;
	}
	
	bytesRead = rv;
	
	rv = unzCloseCurrentFile(self->_zipFile);
	if (rv == UNZ_CRCERROR) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
										 code:FXErrorReadingCompressedFile
									 userInfo:@{ NSLocalizedDescriptionKey : @"CRC error" }];
		}
	}
	
	return data;
}

- (BOOL) locateFileWithCRC:(NSUInteger) crc
					 error:(NSError **) error
{
	int rv = unzGoToFirstFile(self->_zipFile);
	if (rv != UNZ_OK) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
										 code:FXErrorNavigatingArchive
									 userInfo:@{ NSLocalizedDescriptionKey : @"Error rewinding to first file in archive" }];
		}
		
		return NO;
	}
	
	NSUInteger count = [self fileCount];
	for (int i = 0; i < count; i++) {
		unz_file_info fileInfo;
		if (unzGetCurrentFileInfo(self->_zipFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK) {
			continue;
		}
		
		if (crc == fileInfo.crc) {
			return YES;
		}
		
		rv = unzGoToNextFile(self->_zipFile);
		if (rv != UNZ_OK) {
			if (error != NULL) {
				*error = [NSError errorWithDomain:@"org.akop.fbx.Zip"
											 code:FXErrorNavigatingArchive
										 userInfo:@{ NSLocalizedDescriptionKey : @"Error navigating files in the archive" }];
			}
			
			return NO;
		}
	}
	
	return NO;
}

@end
