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

#include "unzip.h"
#include "burner.h"
#include "burnint.h"
#include "driverlist.h"

static FXLoader *sharedInstance = NULL;

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
        self->driverAuditCache = [[NSMutableDictionary alloc] init];
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
    if (driverId >= nBurnDrvCount) {
        if (error != NULL) {
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
    if (driverId >= nBurnDrvCount) {
        if (error != NULL) {
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

- (NSString *)titleForDriverId:(int)driverId
{
    return [NSString stringWithCString:pDriver[driverId]->szFullNameA
                              encoding:NSUTF8StringEncoding];
}

- (FXDriverAudit *)auditDriver:(int)driverId
                         error:(NSError **)error
{
    if (driverId >= nBurnDrvCount) {
        if (error != NULL) {
            *error = [FXLoader newErrorWithDescription:NSLocalizedString(@"ROM set not recognized", @"")
                                                  code:FXRomSetUnrecognized];
        }
        
        return nil;
    }
    
    // Check the cache
    FXDriverAudit *driverAudit = [self->driverAuditCache objectForKey:@(driverId)];
    if (driverAudit != nil) {
        return driverAudit;
    }
    
    // FIXME
    NSArray *romPaths = @[ @"/usr/local/share/roms/",
                           @"roms/", ];
    
    // Get list of archive names for driver
    NSError *archiveError = NULL;
    NSArray *archiveNames = [self archiveNamesForDriver:driverId
                                                  error:&archiveError];
    
    if (archiveError != NULL) {
        if (error != NULL) {
            *error = archiveError;
        }
        
        return nil;
    }
    
    // Get list of components (ROM files) for driver
    NSError *componentError = NULL;
    NSArray *driverComponents = [self componentsForDriver:driverId
                                                    error:&componentError];
    
    if (componentError != NULL) {
        if (error != NULL) {
            *error = componentError;
        }
        
        return nil;
    }
    
    // Create a new audit object
    driverAudit = [[FXDriverAudit alloc] init];
    [driverAudit setDriverId:driverId];
    [driverAudit setArchiveName:[archiveNames firstObject]];
    [driverAudit setName:[self titleForDriverId:driverId]];
    
    // See if any of archives are loadable
    [archiveNames enumerateObjectsUsingBlock:^(NSString *archiveName, NSUInteger idx, BOOL *stop) {
        NSString *archiveFilename = [archiveName stringByAppendingPathExtension:@"zip"];
        [romPaths enumerateObjectsUsingBlock:^(NSString *romPath, NSUInteger idx, BOOL *stop) {
            NSString *fullPath = [romPath stringByAppendingPathComponent:archiveFilename];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath
                                                               isDirectory:NULL];
            
            if (exists) {
                // Open the file, read its table of contents
                NSError *zipError = NULL;
                FXZipArchive *zip = [[FXZipArchive alloc] initWithPath:fullPath
                                                                 error:&zipError];
                
                if (zipError == NULL) {
                    [driverComponents enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger idx, BOOL *stop) {
                        // Extract the BurnRomInfo struct
                        struct BurnRomInfo ri;
                        [value getValue:&ri];
                        
                        NSArray *knownAliases = [self knownAliasesForDriverId:driverId
                                                                     romIndex:(int)idx];
                        
                        FXROMAudit *romAudit = [[FXROMAudit alloc] init];
                        [romAudit setFilenameNeeded:[knownAliases firstObject]];
                        [romAudit setLengthNeeded:ri.nLen];
                        [romAudit setCRCNeeded:ri.nCrc];
                        
                        NSInteger type = FXROMTypeNone;
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
                        } else {
                            // File not found by CRC. Check by known aliases
                            FXZipFile *matchByAlias = [zip findFileNamedAnyOf:knownAliases];
                            if (matchByAlias != nil) {
                                // Found by alias
                                // Update status
                                [romAudit setContainerPath:fullPath];
                                [romAudit setFilenameFound:[matchByAlias filename]];
                                [romAudit setLengthFound:[matchByAlias length]];
                                [romAudit setCRCFound:[matchByAlias CRC]];
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
    [self->driverAuditCache setObject:driverAudit
                               forKey:@(driverId)];
    
    return driverAudit;
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
    
    FXDriverAudit *driverAudit = [self->driverAuditCache objectForKey:@(driverId)];
    if (driverAudit == NULL) {
        return 1;
    }
    
    FXROMAudit *romAudit = [driverAudit ROMAuditByNeededCRC:info.nCrc];
    if (romAudit == nil || [romAudit status] == FXROMAuditMissing) {
        return 1;
    }
    
    NSString *path = [romAudit containerPath];
    NSUInteger uncompressedLength = [romAudit lengthFound];
    NSUInteger foundCRC = [romAudit CRCFound];
    
    NSError *error = NULL;
    // FIXME: keep files open during the loading phase
    FXZipArchive *zipFile = [[FXZipArchive alloc] initWithPath:path
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

- (void)clearCache
{
    [self->driverAuditCache removeAllObjects];
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
