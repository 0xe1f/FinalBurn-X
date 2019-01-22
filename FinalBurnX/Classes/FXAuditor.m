/*****************************************************************************
 **
 ** FinalBurn X: FinalBurn for macOS
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) Akop Karapetyan
 **
 ** Licensed under the Apache License, Version 2.0 (the "License");
 ** you may not use this file except in compliance with the License.
 ** You may obtain a copy of the License at
 **
 **     http://www.apache.org/licenses/LICENSE-2.0
 **
 ** Unless required by applicable law or agreed to in writing, software
 ** distributed under the License is distributed on an "AS IS" BASIS,
 ** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 ** See the License for the specific language governing permissions and
 ** limitations under the License.
 **
 ******************************************************************************
 */
#import "FXAuditor.h"

#import "FXZipArchive.h"
#import "FXManifest.h"

#pragma mark - FXFileAudit

@implementation FXFileAudit

- (instancetype) initWithName:(NSString *) name
					  archive:(NSString *) archive
					   status:(unsigned int) status
{
	if ((self = [super init])) {
		_name = name;
		_archive = archive;
		_status = status;
	}
	
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@: (%@) %d", _name, _archive, _status];
}

@end

#pragma mark - FXDryverAudit

@implementation FXDryverAudit

- (instancetype) initWithFiles:(NSArray<FXFileAudit *> *) files
{
	if ((self = [super init])) {
		_files = [NSArray arrayWithArray:files];
	}
	
	return self;
}

- (NSString *) description
{
	return [_files description];
}

@end

#pragma mark - FXAuditor

@implementation FXAuditor

- (instancetype) initWithRoot:(NSString *) root
{
	if ((self = [super init])) {
		_root = root;
	}

	return self;
}

- (NSString *) archivePathForDriver:(FXDriver *) driver
{
	return [_root stringByAppendingPathComponent:[[driver name] stringByAppendingPathExtension:@"zip"]];
}

- (FXDryverAudit *) auditDriver:(FXDriver *) theDriver
{
	NSMutableDictionary<NSString *, FXFileAudit *> *audits = [NSMutableDictionary dictionary];
	NSMutableDictionary<NSString *, FXZipArchive *> *archives = [NSMutableDictionary dictionary];
	
	NSMutableArray<NSString *> *required = [NSMutableArray arrayWithArray:[[theDriver files] allKeys]];
	[required addObjectsFromArray:[theDriver parentFiles]];
	NSMutableDictionary<NSString *, FXDriverFile *> *files = [NSMutableDictionary dictionary];
	
	[required enumerateObjectsUsingBlock:^(NSString *req, NSUInteger idx, BOOL *stop) {
		FXDriver *driver = theDriver;
		unsigned int status = FILE_AUDIT_MISSING;
		NSString *archivePath;
		
		do {
			FXDriverFile *file = [files objectForKey:req];
			if (!file && (file = [[driver files] objectForKey:req])) {
				[files setObject:file
						  forKey:req];
			}
			
			if (!file) {
				continue;
			}
			
			NSString *driverArchivePath = [self archivePathForDriver:driver];
			FXZipArchive *archive = [archives objectForKey:driverArchivePath];
			if (!archive) {
				// FIXME
				NSError *error = nil;
				archive = [[FXZipArchive alloc] initWithPath:driverArchivePath
													   error:&error];
				if (error) {
					continue;
				}
				
				[archives setObject:archive
							 forKey:driverArchivePath];
			}
			
			archivePath = [archive path];
			
			if ([file crc]) {
				if ([archive findFileWithCRC:[file crc]]) {
					status = FILE_AUDIT_OK;
					break; // Found it; stop climbing up tree
				} else if ([archive findFileNamed:[file name]
								   matchExactPath:NO]) {
					status = FILE_AUDIT_BAD;
				}
			} else if ([archive findFileNamed:[file name]
							   matchExactPath:NO]) {
				status = FILE_AUDIT_UNKNOWN;
			}
		} while ((driver = [driver parent]));
		
		[audits setObject:[[FXFileAudit alloc] initWithName:req
													archive:archivePath
													 status:status]
				   forKey:req];
	}];
	
	return [[FXDryverAudit alloc] initWithFiles:[audits allValues]];
}

@end
