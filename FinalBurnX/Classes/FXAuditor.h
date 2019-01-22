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
#import <Foundation/Foundation.h>

@class FXDriver;

#define FILE_AUDIT_MISSING 0
#define FILE_AUDIT_BAD     1
#define FILE_AUDIT_UNKNOWN 2
#define FILE_AUDIT_OK      3

@interface FXFileAudit : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) unsigned int status;
@property (nonatomic, readonly) NSString *archive;

@end

@interface FXDryverAudit : NSObject /* FIXME: name */

@property (nonatomic, readonly) NSArray<FXFileAudit *> *files;

@end

@interface FXAuditor : NSObject

@property (nonatomic, readonly) NSString *root;

- (instancetype) initWithRoot:(NSString *) root;

- (FXDryverAudit *) auditDriver:(FXDriver *) theDriver;

@end
