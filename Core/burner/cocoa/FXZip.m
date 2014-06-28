/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014 Akop Karapetyan
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
#import "FXZip.h"

#include "unzip.h"

#pragma mark - FXZip

@interface FXZip ()

- (void)invalidateEntryCache;
+ (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode;

@end

@implementation FXZip

- (instancetype)initWithPath:(NSString *)path
                       error:(NSError **)error
{
    if (self = [super init]) {
        const char *cpath = [path cStringUsingEncoding:NSUTF8StringEncoding];
        self->zipFile = unzOpen(cpath);
        if (self->zipFile != NULL) {
            [self setPath:path];
        } else {
            if (error != NULL) {
                *error = [FXZip newErrorWithDescription:@"Error loading compressed file"
                                                   code:FXErrorLoadingZip];
            }
        }
    }
    
    return self;
}

- (void)invalidateEntryCache
{
    self->entryCache = nil;
}

- (FXROM *)findROMWithCRC:(NSUInteger)crc
{
    __block FXROM *matching = nil;
    [[self entries] enumerateObjectsUsingBlock:^(FXROM *file, NSUInteger idx, BOOL *stop) {
        if ([file CRC] == crc) {
            matching = file;
            *stop = YES;
        }
    }];
    
    return matching;
}

- (FXROM *)findROMNamed:(NSString *)filename
{
    __block FXROM *matching = nil;
    [[self entries] enumerateObjectsUsingBlock:^(FXROM *file, NSUInteger idx, BOOL *stop) {
        if ([[file filename] isEqualToString:filename]) {
            matching = file;
            *stop = YES;
        }
    }];
    
    return matching;
}

- (FXROM *)findROMNamedAnyOf:(NSArray *)filenames
{
    __block FXROM *matching = nil;
    [filenames enumerateObjectsUsingBlock:^(NSString *filename, NSUInteger idx, BOOL *stop) {
        FXROM *file = [self findROMNamed:filename];
        if (file != nil) {
            matching = file;
            *stop = YES;
        }
    }];
    
    return matching;
}

- (NSArray *)entries
{
    if (entryCache == nil) {
        NSMutableArray *entries = [[NSMutableArray alloc] init];
        if (self->zipFile != NULL) {
            // Get the global info block
            unz_global_info globalInfo;
            memset(&globalInfo, 0, sizeof(globalInfo));
            unzGetGlobalInfo(self->zipFile, &globalInfo);
            
            // Loop through files
            unsigned long n = globalInfo.number_entry;
            for (int i = 0, rv = unzGoToFirstFile(self->zipFile);
                 i < n && rv == UNZ_OK;
                 i++, rv = unzGoToNextFile(self->zipFile)) {
                // Get individual file record
                unz_file_info fileInfo;
                memset(&fileInfo, 0, sizeof(fileInfo));
                
                if (unzGetCurrentFileInfo(self->zipFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK) {
                    continue;
                }
                
                // Allocate space for the filename
                NSInteger filenameLen = fileInfo.size_filename + 1;
                char *cFilename = (char *)malloc(filenameLen);
                if (cFilename == NULL) {
                    continue;
                }
                
                if (unzGetCurrentFileInfo(self->zipFile, &fileInfo, cFilename, filenameLen, NULL, 0, NULL, 0) != UNZ_OK) {
                    free(cFilename);
                    continue;
                }
                
                FXROM *rom = [[FXROM alloc] init];
                [rom setFilename:[NSString stringWithCString:cFilename
                                                     encoding:NSUTF8StringEncoding]];
                [rom setCRC:fileInfo.crc];
                [rom setLength:fileInfo.uncompressed_size];
                
                free(cFilename);
                
                [entries addObject:rom];
            }
        }
        
        entryCache = entries;
    }
    
    return entryCache;
}

- (void)dealloc
{
    if (self->zipFile != NULL) {
        unzClose(self->zipFile);
        self->zipFile = NULL;
    }
}

#pragma mark - Errors

+ (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode
{
    NSString *domain = @"org.akop.fbx.Emulation";
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
    
    return [NSError errorWithDomain:domain
                               code:errorCode
                           userInfo:userInfo];
}

@end
