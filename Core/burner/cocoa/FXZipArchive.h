/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
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
#import <Foundation/Foundation.h>

#import "FXZipFile.h"

#include "unzip.h"

@interface FXZipArchive : NSObject
{
    @private
    unzFile zipFile;
    NSArray *fileCache;
}

@property (nonatomic, strong) NSString *path;

- (instancetype)initWithPath:(NSString *)path
                       error:(NSError **)error;
- (NSArray *)files;
- (NSUInteger)fileCount;
- (FXZipFile *)findFileWithCRC:(NSUInteger)crc;
- (FXZipFile *)findFileNamed:(NSString *)filename
              matchExactPath:(BOOL)exactPath;
- (FXZipFile *)findFileNamedAnyOf:(NSArray *)filenames
                   matchExactPath:(BOOL)exactPath;
- (UInt32)readFileWithCRC:(NSUInteger)crc
               intoBuffer:(void *)buffer
             bufferLength:(NSUInteger)length
                    error:(NSError **)error;

@end

enum {
    FXErrorLoadingArchive        = -100,
    FXErrorNavigatingArchive     = -101,
    FXErrorOpeningCompressedFile = -102,
    FXErrorReadingCompressedFile = -103,
};
