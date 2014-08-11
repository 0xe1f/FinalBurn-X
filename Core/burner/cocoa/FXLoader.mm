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

#import "FXZipArchive.h"
#import "FXAppDelegate.h"

#include <wchar.h>

#include "unzip.h"
#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

@interface FXLoader()

- (int)driverIndexForArchive:(NSString *)archive;
- (NSArray *)componentsForDriver:(int)driverId
                           error:(NSError **)error;
- (NSArray *)knownAliasesForDriverId:(int)driverId
                            romIndex:(int)romIndex;
- (NSString *)archiveNameForDriverId:(int)driverId;

@end

@implementation FXLoader

- (instancetype)init
{
    if (self = [super init]) {
    }
    
    return self;
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

- (int)driverIndexForArchive:(NSString *)archive
{
    const char *cArchive = [archive cStringUsingEncoding:NSASCIIStringEncoding];
    
    int driverId = -1;
    for (int i = 0; i < nBurnDrvCount; i++) {
        if (strcmp(pDriver[i]->szShortName, cArchive) == 0) {
            driverId = i;
            break;
        }
    }
    
    return driverId;
}

- (NSString *)archiveNameForDriverId:(int)driverId
{
    return [NSString stringWithCString:pDriver[driverId]->szShortName
                              encoding:NSUTF8StringEncoding];
}

- (NSArray *)knownAliasesForDriverId:(int)driverId
                            romIndex:(int)romIndex
{
    NSMutableArray *aliases = [[NSMutableArray alloc] init];
    for (int aliasIndex = 0; aliasIndex < 0x10000; aliasIndex++) {
        char *cAlias = NULL;
        if (pDriver[driverId]->GetRomName(&cAlias, romIndex, aliasIndex)) {
            break;
        }
        
        NSString *alias = [NSString stringWithCString:cAlias
                                             encoding:NSUTF8StringEncoding];
        
        [aliases addObject:alias];
    }
    
    return aliases;
}

- (NSArray *)romSets
{
    // Create a map of archive to driver id
    NSMutableDictionary *indexMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *setMap = [NSMutableDictionary dictionary];
    
    for (int index = 0; index < nBurnDrvCount; index++) {
        UInt32 hardware = pDriver[index]->Hardware & HARDWARE_PUBLIC_MASK;
        if ((hardware != HARDWARE_CAPCOM_CPS1) &&
            (hardware != HARDWARE_CAPCOM_CPS1_GENERIC) &&
            (hardware != HARDWARE_CAPCOM_CPS1_QSOUND) &&
            (hardware != HARDWARE_CAPCOM_CPS2) &&
            (hardware != HARDWARE_CAPCOM_CPS2_SIMM) &&
            (hardware != HARDWARE_CAPCOM_CPS3) &&
            (hardware != HARDWARE_CAPCOM_CPS3_NO_CD) &&
            (hardware != (HARDWARE_SNK_NEOGEO | HARDWARE_PREFIX_CARTRIDGE))) {
            // Don't care
            continue;
        }
        
        NSString *archive = [self archiveNameForDriverId:index];
        [indexMap setObject:@(index) forKey:archive];
        
        FXROMSet *romSet = [[FXROMSet alloc] initWithArchive:archive];
        [setMap setObject:romSet forKey:archive];
    }
    
    NSMutableArray *romSets = [NSMutableArray array];
    [setMap enumerateKeysAndObjectsUsingBlock:^(NSString *archive, FXROMSet *romSet, BOOL *stop) {
        int driverIndex = [[indexMap objectForKey:archive] intValue];
        
        if (pDriver[driverIndex]->szParent != NULL) {
            NSString *parentArchive = [NSString stringWithCString:pDriver[driverIndex]->szParent
                                                         encoding:NSUTF8StringEncoding];
            FXROMSet *parentSet = [setMap objectForKey:parentArchive];
            
            [[parentSet subsets] addObject:romSet];
            [romSet setParentSet:parentSet];
        } else {
            [romSets addObject:romSet];
        }
    }];
    
    return romSets;
}

- (NSArray *)componentsForDriver:(int)driverId
                           error:(NSError **)error
{
    if (driverId < 0 || driverId >= nBurnDrvCount) {
        if (error != nil) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    
    struct BurnRomInfo ri;
    for (int i = 0; ; i++) {
        if (pDriver[driverId]->GetRomInfo(&ri, i)) {
            break;
        }
        
        NSValue *value = [NSValue valueWithBytes:&ri
                                        objCType:@encode(struct BurnRomInfo)];
        
        [array addObject:value];
    }
    
    return array;
}

- (NSArray *)archiveNamesForDriver:(int)driverId
                             error:(NSError **)error
{
    if (driverId < 0 || driverId >= nBurnDrvCount) {
        if (error != nil) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < BZIP_MAX; i++) {
        char *name = NULL;
        if (pDriver[driverId]->GetZipName) {
            if (pDriver[driverId]->GetZipName(&name, i)) {
                break;
            }
        } else {
            if (i == 0) {
                name = pDriver[driverId]->szShortName;
            } else {
                UINT32 j = pDriver[driverId]->szBoardROM ? 1 : 0;
                
                // Try BIOS/board ROMs first
                if (i == 1 && j == 1) {
                    name = pDriver[driverId]->szBoardROM;
                }
                
                if (name == NULL) {
                    // Find the immediate parent
                    int drv = driverId;
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

- (FXDriverAudit *)auditSet:(FXROMSet *)romSet
                      error:(NSError **)error
{
    int driverIndex = [self driverIndexForArchive:[romSet archive]];
    if (driverIndex < 0 || driverIndex >= nBurnDrvCount) {
        if (error != nil) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSArray *romPaths = @[[[FXAppDelegate sharedInstance] ROMPath]];
    
    // Get list of archive names for driver
    NSError *archiveError = nil;
    NSArray *archiveNames = [self archiveNamesForDriver:driverIndex
                                                  error:&archiveError];
    
    if (archiveError != nil) {
        if (error != nil) {
            *error = archiveError;
        }
        
        return nil;
    }
    
    // Get list of components (ROM files) for driver
    NSError *componentError = nil;
    NSArray *driverComponents = [self componentsForDriver:driverIndex
                                                    error:&componentError];
    
    if (componentError != nil) {
        if (error != nil) {
            *error = componentError;
        }
        
        return nil;
    }
    
    // Create a new audit object
    FXDriverAudit *driverAudit = [[FXDriverAudit alloc] init];
    NSMutableArray *foundComponentIndices = [NSMutableArray array];
    
    [archiveNames enumerateObjectsUsingBlock:^(NSString *archiveName, NSUInteger idx, BOOL *stop) {
        NSString *archiveFilename = [archiveName stringByAppendingPathExtension:@"zip"];
        [romPaths enumerateObjectsUsingBlock:^(NSString *romPath, NSUInteger idx, BOOL *stop) {
            NSString *fullPath = [romPath stringByAppendingPathComponent:archiveFilename];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath
                                                               isDirectory:NULL];
            
            if (exists) {
                // Open the file, read its table of contents
                NSError *zipError = nil;
                FXZipArchive *zip = [[FXZipArchive alloc] initWithPath:fullPath
                                                                 error:&zipError];
                
                if (zipError == nil) {
                    [driverComponents enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger idx, BOOL *stop) {
                        // Extract the BurnRomInfo struct
                        struct BurnRomInfo ri;
                        [value getValue:&ri];
                        
                        if (ri.nType == 0) {
                            // No ROM in slot
                            return;
                        } else if ([foundComponentIndices containsObject:@(idx)]) {
                            // Already found in an earlier set
                            return;
                        }
                        
                        NSArray *knownAliases = [self knownAliasesForDriverId:driverIndex
                                                                     romIndex:(int)idx];
                        
                        FXROMAudit *romAudit = [[FXROMAudit alloc] init];
                        [romAudit setFilenameNeeded:[knownAliases firstObject]];
                        [romAudit setLengthNeeded:ri.nLen];
                        [romAudit setCRCNeeded:ri.nCrc];
                        
                        NSInteger type = FXROMTypeNone;
                        if (idx < 0x80) {
                            // Not sure if this is a good idea; basing it off
                            // STD_ROM_PICK to determine whether or not a ROM
                            // is part of the original set
                            type |= FXROMTypeCoreSet;
                        }
                        if (ri.nType & 0x90) {
                            type |= FXROMTypeEssential;
                        }
                        if (ri.nType & 0x01) {
                            type |= FXROMTypeGraphics;
                        }
                        if (ri.nType & 0x02) {
                            type |= FXROMTypeSound;
                        }
                        
                        [romAudit setType:type];
                        
                        FXZipFile *matchByCRC = [zip findFileWithCRC:ri.nCrc];
                        if (matchByCRC != nil) {
                            // Found by CRC
                            // Update status
                            [romAudit setContainerPath:fullPath];
                            [romAudit setFilenameFound:[matchByCRC filename]];
                            [romAudit setLengthFound:[matchByCRC length]];
                            [romAudit setCRCFound:[matchByCRC CRC]];
                            
                            [foundComponentIndices addObject:@(idx)];
                        } else {
                            // File not found by CRC. Check by known aliases
                            FXZipFile *matchByAlias = [zip findFileNamedAnyOf:knownAliases
                                                               matchExactPath:NO];
                            
                            if (matchByAlias != nil) {
                                // Found by alias
                                // Update status
                                [romAudit setContainerPath:fullPath];
                                [romAudit setFilenameFound:[matchByAlias filename]];
                                [romAudit setLengthFound:[matchByAlias length]];
                                [romAudit setCRCFound:[matchByAlias CRC]];
                                
                                [foundComponentIndices addObject:@(idx)];
                            } else {
                                // File not found by any of known aliases
                            }
                        }
                        
                        [[driverAudit romAudits] addObject:romAudit];
                    }];
                }
            }
        }];
    }];
    
    [driverAudit updateAvailability];
    
    return driverAudit;
}

@end
