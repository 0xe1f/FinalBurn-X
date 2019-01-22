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
#import "FXLoader.h"

#import "FXZipArchive.h"
#import "FXAppDelegate.h"
#import "FXManifest.h"

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

- (void)updateStatus:(FXROMAudit *)romAudit;
- (void)updateAvailability:(FXDriverAudit *)driverAudit;

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

- (NSArray *) componentsForDriver:(int) driverId
							error:(NSError **) error
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

- (FXDriverAudit *) auditDriver:(FXDriver *) driver
						  error:(NSError **) error
{
	int driverIndex = [driver index];
    NSArray *romPaths = @[[[FXAppDelegate sharedInstance] romPath]];
    
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
    NSMutableDictionary *romAudits = [NSMutableDictionary dictionary];
    NSMutableDictionary *aliasDict = [NSMutableDictionary dictionary];
    
    [driverComponents enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger idx, BOOL *stop) {
        // Extract the BurnRomInfo struct
        struct BurnRomInfo ri;
        [value getValue:&ri];
        
        if (ri.nType == 0) {
            // No ROM in slot
            return;
        }
        
        NSArray *aliases = [self knownAliasesForDriverId:driverIndex
                                                romIndex:(int)idx];
        [aliasDict setObject:aliases
                      forKey:@(idx)];
        
        FXROMAudit *romAudit = romAudit = [[FXROMAudit alloc] init];
        [romAudit setFilenameNeeded:[aliases firstObject]];
        [romAudit setLengthNeeded:ri.nLen];
        [romAudit setCRCNeeded:ri.nCrc];
        
        NSInteger type = FXROMTypeNone;
        if (ri.nType & BRF_ESS) {
            type |= FXROMTypeEssential;
        }
        if (ri.nType & BRF_BIOS) {
            type |= FXROMTypeBIOS;
        }
        if (ri.nType & BRF_GRA) {
            type |= FXROMTypeGraphics;
        }
        if (ri.nType & BRF_SND) {
            type |= FXROMTypeSound;
        }
        [romAudit setType:type];
        
        [romAudits setObject:romAudit forKey:@(idx)];
        [[driverAudit romAudits] addObject:romAudit];
        
        [self updateStatus:romAudit];
    }];
    
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
                        }
                        
                        NSArray *aliases = [aliasDict objectForKey:@(idx)];
                        FXROMAudit *romAudit = [romAudits objectForKey:@(idx)];
                        
                        if ([romAudit isExactMatch]) {
                            // Already have an exact match
                            return;
                        }
                        
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
                            FXZipFile *matchByAlias = [zip findFileNamedAnyOf:aliases
                                                               matchExactPath:NO];
                            
                            if (matchByAlias != nil) {
                                // Found by alias
                                // Update status
                                [romAudit setContainerPath:fullPath];
                                [romAudit setFilenameFound:[matchByAlias filename]];
                                [romAudit setLengthFound:[matchByAlias length]];
                                [romAudit setCRCFound:[matchByAlias CRC]];
                            }
                        }
                        
                        [self updateStatus:romAudit];
                    }];
                }
            }
        }];
    }];
    
    [self updateAvailability:driverAudit];
    if ([[driver name] isEqualTo:@"neogeo"]) {
        [driverAudit setIsPlayable:NO];
    }
    
    return driverAudit;
}

- (void)updateStatus:(FXROMAudit *)romAudit
{
    if ([romAudit filenameFound] == nil) {
        [romAudit setStatusCode:FXROMAuditMissing];
        [romAudit setStatusDescription:NSLocalizedString(@"Missing", @"")];
    } else {
        if ([romAudit CRCNeeded] == [romAudit CRCFound]) {
            [romAudit setStatusCode:FXROMAuditOK];
            [romAudit setStatusDescription:NSLocalizedString(@"OK", @"")];
        } else if ([romAudit lengthFound] != [romAudit lengthNeeded]) {
            [romAudit setStatusCode:FXROMAuditBadLength];
            [romAudit setStatusDescription:[NSString stringWithFormat:NSLocalizedString(@"Length mismatch (expected: %dkB; found: %dkB)", @""), [romAudit lengthNeeded] >> 10, [romAudit lengthFound] >> 10]];
        } else {
            [romAudit setStatusCode:FXROMAuditBadCRC];
            [romAudit setStatusDescription:[NSString stringWithFormat:NSLocalizedString(@"Checksum mismatch (expected: 0x%08x; found: 0x%08x)", @""), [romAudit CRCNeeded], [romAudit CRCFound]]];
        }
    }
}

- (void)updateAvailability:(FXDriverAudit *)driverAudit
{
    __block NSInteger availability = FXDriverComplete;
    
    [[driverAudit romAudits] enumerateObjectsUsingBlock:^(FXROMAudit *romAudit, NSUInteger idx, BOOL *stop) {
        if ([romAudit statusCode] == FXROMAuditOK) {
            // ROM present and correct
        } else if ([romAudit statusCode] == FXROMAuditMissing) {
            // ROM missing
            availability = FXDriverMissing;
            *stop = YES;
        } else {
            // ROM present, but CRC or length don't match
            availability = FXDriverPartial;
        }
    }];
    
    [driverAudit setIsPlayable:(availability == FXDriverComplete || availability == FXDriverPartial)];
    [driverAudit setAvailability:availability];
}

@end
