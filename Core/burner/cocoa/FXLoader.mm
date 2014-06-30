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
#import "FXLoader.h"

#import "FXZip.h"
#import "FXROMInfo.h"
#import "FXROMSetStatus.h"
#import "FXROMStatus.h"

#include "unzip.h"
#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

static NSString * const FXROMCacheFoundPathKey = @"foundPath";
static NSString * const FXROMCacheFoundCRCKey  = @"foundCRC";
static NSString * const FXROMCacheROMLengthKey = @"romLength";

static FXLoader *sharedInstance = NULL;

@implementation FXLoader

- (instancetype)init
{
    if (self = [super init]) {
        romCache = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

+ (id)sharedLoader
{
    if (sharedInstance == NULL) {
        sharedInstance = [[FXLoader alloc] init];
    }
    
    return sharedInstance;
}

+ (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode
{
    NSString *domain = @"org.akop.fbx.Emulation";
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
    
    return [NSError errorWithDomain:domain
                               code:errorCode
                           userInfo:userInfo];
}

- (int)driverIdForName:(NSString *)driverName
{
    const char *cDriverName = [driverName cStringUsingEncoding:NSUTF8StringEncoding];
    
    int driverId = -1;
    for (int i = 0; i < nBurnDrvCount; i++) {
        if (strcmp(pDriver[i]->szShortName, cDriverName) == 0) {
            driverId = i;
            break;
        }
    }
    
    return driverId;
}

- (NSArray *)componentsForDriver:(int)romIndex
                           error:(NSError **)error
{
    if (romIndex >= nBurnDrvCount) {
        if (error != NULL) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    
    struct BurnRomInfo ri;
    for (int i = 0; ; i++) {
        if (pDriver[romIndex]->GetRomInfo(&ri, i)) {
            break;
        }
        
        FXROMInfo *info = [[FXROMInfo alloc] initWithBurnROMInfo:&ri];
        
        for (int aliasIndex = 0; aliasIndex < 0x10000; aliasIndex++) {
            char *cAlias = NULL;
            if (pDriver[romIndex]->GetRomName(&cAlias, i, aliasIndex)) {
                break;
            }
            
            NSString *alias = [NSString stringWithCString:cAlias
                                                 encoding:NSUTF8StringEncoding];
            
            [info addKnownAlias:alias];
        }
        
        [array addObject:info];
    }
    
    return array;
}

- (NSArray *)archiveNamesForDriver:(int)romIndex
                             error:(NSError **)error
{
    if (romIndex >= nBurnDrvCount) {
        if (error != NULL) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < BZIP_MAX; i++) {
        char *name = NULL;
        if (pDriver[romIndex]->GetZipName) {
            if (pDriver[romIndex]->GetZipName(&name, i)) {
                break;
            }
        } else {
            if (i == 0) {
                name = pDriver[romIndex]->szShortName;
            } else {
                UINT32 j = pDriver[romIndex]->szBoardROM ? 1 : 0;
                
                // Try BIOS/board ROMs first
                if (i == 1 && j == 1) {
                    name = pDriver[romIndex]->szBoardROM;
                }
                
                if (name == NULL) {
                    // Find the immediate parent
                    int drv = romIndex;
                    while (j < i) {
                        char *pszParent = pDriver[drv]->szParent;
                        name = NULL;
                        
                        if (pszParent == NULL) {
                            break;
                        }
                        
                        for (drv = 0; drv < nBurnDrvCount; drv++) {
                            if (strcmp(pszParent, pDriver[drv]->szShortName) == 0) {
                                name = pDriver[drv]->szShortName;
                                break;
                            }
                        }
                        
                        j++;
                    }
                }
            }
            
            if (name == NULL) {
                break;
            }
        }
        
        if (name != NULL) {
            [array addObject:[NSString stringWithCString:name
                                                 encoding:NSUTF8StringEncoding]];
        }
    }
    
    return array;
}

- (NSArray *)scanROMSetIndex:(int)romIndex
                       error:(NSError **)error
{
    // FIXME
    NSArray *romPaths = @[ @"/usr/local/share/roms/",
                           @"roms/", ];
    
    // Get list of archive names for driver
    NSError *archiveError = NULL;
    NSArray *archiveNames = [self archiveNamesForDriver:romIndex
                                                  error:&archiveError];
    
    if (archiveError != NULL) {
        *error = archiveError;
        return nil;
    }
    
    // Get list of components (ROM files) for driver
    NSError *compError = NULL;
    NSArray *driverComponents = [self componentsForDriver:romIndex
                                                    error:&compError];
    
    if (compError != NULL) {
        *error = compError;
        return nil;
    }
    
    __block NSError *localErr = NULL;
    
    NSMutableArray *setStatuses = [[NSMutableArray alloc] init];
    
    // See if any of archives are loadable
    [archiveNames enumerateObjectsUsingBlock:^(NSString *archiveName, NSUInteger idx, BOOL *stop) {
        NSString *archiveFilename = [archiveName stringByAppendingPathExtension:@"zip"];
        [romPaths enumerateObjectsUsingBlock:^(NSString *romPath, NSUInteger idx, BOOL *stop) {
            NSString *fullPath = [romPath stringByAppendingPathComponent:archiveFilename];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath
                                                               isDirectory:NULL];
            
            FXROMSetStatus *setStatus = [[FXROMSetStatus alloc] initWithArchiveNamed:archiveName];
            
            if (exists) {
                [setStatus setPath:fullPath];
                
                // Open the file, read its table of contents
                FXZip *zip = [[FXZip alloc] initWithPath:fullPath
                                                   error:&localErr];
                
                if (localErr == NULL) {
                    [driverComponents enumerateObjectsUsingBlock:^(FXROMInfo *romInfo, NSUInteger idx, BOOL *stop) {
                        FXROMStatus *status = [[FXROMStatus alloc] init];
                        [status setFilenameNeeded:[[romInfo knownAliases] firstObject]];
                        [status setLengthNeeded:[romInfo length]];
                        [status setCRCNeeded:[romInfo crc]];
                        [status setType:[romInfo type]];
                        
                        FXROM *matchByCRC = [zip findROMWithCRC:[romInfo crc]];
                        if (matchByCRC == nil) {
                            // File not found by CRC. Check by known aliases
                            FXROM *matchByAlias = [zip findROMNamedAnyOf:[romInfo knownAliases]];
                            if (matchByAlias == nil) {
                                // File not found by known aliases
                            } else {
                                // Found by alias
                                
                                // Update cache
                                [romCache setObject:@{FXROMCacheFoundPathKey: fullPath,
                                                      FXROMCacheFoundCRCKey: @([matchByAlias CRC]),
                                                      FXROMCacheROMLengthKey: @([romInfo length]), }
                                             forKey:@([romInfo crc])];
                                
                                // Update status
                                [status setFilenameFound:[matchByAlias filename]];
                                [status setLengthFound:[matchByAlias length]];
                                [status setCRCFound:[matchByAlias CRC]];
                            }
                        } else {
                            // Update cache
                            [romCache setObject:@{FXROMCacheFoundPathKey: fullPath,
                                                  FXROMCacheFoundCRCKey: @([matchByCRC CRC]),
                                                  FXROMCacheROMLengthKey: @([romInfo length]), }
                                         forKey:@([romInfo crc])];
                            
                            // Update status
                            [status setFilenameFound:[matchByCRC filename]];
                            [status setLengthFound:[matchByCRC length]];
                            [status setCRCFound:[matchByCRC CRC]];
                        }
                        
                        [setStatus addROMStatus:status];
                    }];
                }
            }
            
            [setStatuses addObject:setStatus];
        }];
    }];
    
    return setStatuses;
}

- (UInt32)loadROMOfDriver:(int)driverId
                    index:(int)romIndex
               intoBuffer:(void *)buffer
             bufferLength:(int *)length
{
    if (driverId >= nBurnDrvCount) {
        return 1;
    }
    
    struct BurnRomInfo info;
    if (pDriver[driverId]->GetRomInfo(&info, romIndex)) {
        return 1;
    }
    
    NSDictionary *cacheContents = [romCache objectForKey:@(info.nCrc)];
    if (cacheContents == nil) {
        return 1;
    }
    
    NSString *path = [cacheContents objectForKey:FXROMCacheFoundPathKey];
    NSUInteger uncompressedLength = [[cacheContents objectForKey:FXROMCacheROMLengthKey] unsignedIntegerValue];
    NSUInteger foundCRC = [[cacheContents objectForKey:FXROMCacheFoundCRCKey] unsignedIntegerValue];
    
    NSError *error = NULL;
    // FIXME: keep files open during the loading phase
    FXZip *zipFile = [[FXZip alloc] initWithPath:path
                                           error:&error];
    
    if (error != NULL) {
        return 1;
    }
    
    UInt32 bytesRead = [zipFile readFileWithCRC:foundCRC
                                     intoBuffer:buffer
                                   bufferLength:uncompressedLength
                                          error:&error];
    
    if (error != NULL) {
        if (bytesRead > -1) {
            if (length != NULL) {
                *length = bytesRead;
            }
            
            return 2;
        }
        
        return 1;
    }
    
    if (length != NULL) {
        *length = bytesRead;
    }
    
    NSLog(@"%d/%d found in %@, read %d bytes", driverId, romIndex, path, bytesRead);
    
    return 0;
}

@end

#pragma mark - FinalBurn callbacks

int cocoaLoadROMCallback(unsigned char *Dest, int *pnWrote, int i)
{
    return [sharedInstance loadROMOfDriver:nBurnDrvActive
                                     index:i
                                intoBuffer:Dest
                              bufferLength:pnWrote];
}
