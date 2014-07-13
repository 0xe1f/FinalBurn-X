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

- (NSArray *)componentsForDriver:(int)driverId
                           error:(NSError **)error;
- (NSArray *)knownAliasesForDriverId:(int)driverId
                            romIndex:(int)romIndex;

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

- (NSDictionary *)drivers
{
    NSMutableDictionary *parentMap = [NSMutableDictionary dictionary];
    
    // Parentless items
    NSMutableArray *parentlessIds = [NSMutableArray array];
    NSMutableArray *parentlessNames = [NSMutableArray array];
    
    for (int driverId = 0; driverId < nBurnDrvCount; driverId++) {
        UInt32 hardware = pDriver[driverId]->Hardware & HARDWARE_PUBLIC_MASK;
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
        
        if (pDriver[driverId]->szParent != NULL) {
            // Place drivers with parents into a dictionary where the key is
            // the parent driver's name and value is an array of child ID's
            NSString *parentName = [NSString stringWithCString:pDriver[driverId]->szParent
                                                      encoding:NSUTF8StringEncoding];
            
            NSMutableArray *children = [parentMap objectForKey:parentName];
            if (children == nil) {
                children = [NSMutableArray array];
                [parentMap setObject:children forKey:parentName];
            }
            
            [children addObject:@(driverId)];
        } else {
            NSString *name = [NSString stringWithCString:pDriver[driverId]->szShortName
                                                encoding:NSUTF8StringEncoding];
            
            [parentlessIds addObject:@(driverId)];
            [parentlessNames addObject:name];
        }
    }
    
    // Now turn this information into a dictionary where keys are
    // parentless driver ids and values are NSArrays containing zero or more
    // driver ids
    NSMutableDictionary *drivers = [NSMutableDictionary dictionary];
    [parentlessIds enumerateObjectsUsingBlock:^(NSNumber *driverId, NSUInteger idx, BOOL *stop) {
        NSString *parentName = [parentlessNames objectAtIndex:idx];
        NSArray *children = [parentMap objectForKey:parentName];
        
        if (children == nil) {
            children = [NSMutableArray array];
        }
        
        [drivers setObject:children forKey:driverId];
    }];
    
    return drivers;
}

- (NSArray *)componentsForDriver:(int)driverId
                           error:(NSError **)error
{
    if (![FXROMSet isDriverIdValid:driverId]) {
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
    if (![FXROMSet isDriverIdValid:driverId]) {
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

- (FXDriverAudit *)auditDriver:(int)driverId
                         error:(NSError **)error
{
    if (![FXROMSet isDriverIdValid:driverId]) {
        if (error != nil) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    NSArray *romPaths = @[[[FXAppDelegate sharedInstance] ROMPath]];
    
    // Get list of archive names for driver
    NSError *archiveError = nil;
    NSArray *archiveNames = [self archiveNamesForDriver:driverId
                                                  error:&archiveError];
    
    if (archiveError != nil) {
        if (error != nil) {
            *error = archiveError;
        }
        
        return nil;
    }
    
    // Get list of components (ROM files) for driver
    NSError *componentError = nil;
    NSArray *driverComponents = [self componentsForDriver:driverId
                                                    error:&componentError];
    
    if (componentError != nil) {
        if (error != nil) {
            *error = componentError;
        }
        
        return nil;
    }
    
    // Create a new audit object
    FXDriverAudit *driverAudit = [[FXDriverAudit alloc] init];
    [driverAudit setDriverId:driverId];
    [driverAudit setArchiveName:[archiveNames firstObject]];
    [driverAudit setName:[FXROMSet titleOfSetWithDriverId:driverId]];
    
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
                        
                        NSArray *knownAliases = [self knownAliasesForDriverId:driverId
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
                        
                        [driverAudit addROMAudit:romAudit];
                    }];
                }
            }
        }];
    }];
    
    [driverAudit updateAvailability];
    
    return driverAudit;
}

@end
