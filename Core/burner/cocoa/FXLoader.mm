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

@implementation FXLoader

+ (NSError *)newErrorWithDescription:(NSString *)desc
                                code:(NSInteger)errorCode
{
    NSString *domain = @"org.akop.fbx.Emulation";
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
    
    return [NSError errorWithDomain:domain
                               code:errorCode
                           userInfo:userInfo];
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
    
    // FIXME
//    if (archiveError != NULL) {
//        *error = *archiveError;
//        return NO;
//    }
    
    // Get list of components (ROM files) for driver
    NSError *compError = NULL;
    NSArray *driverComponents = [self componentsForDriver:romIndex
                                                    error:&compError];
    
    // FIXME
//    if (compError != NULL) {
//        *error = *compError;
//        return NO;
//    }
    
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
                                [status setFilenameFound:[matchByAlias filename]];
                                [status setLengthFound:[matchByAlias length]];
                                [status setCRCFound:[matchByAlias CRC]];
                            }
                        } else {
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

@end
