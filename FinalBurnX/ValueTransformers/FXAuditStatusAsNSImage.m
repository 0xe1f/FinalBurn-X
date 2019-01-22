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
#import "FXAuditStatusAsNSImage.h"

#import "FXDriverAudit.h"

static NSMutableDictionary *icons;

@implementation FXAuditStatusAsNSImage

+ (void)initialize
{
    icons = [[NSMutableDictionary alloc] init];
}

+ (Class)transformedValueClass
{
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (NSImage *)imageNamed:(NSString *)name
{
    // Keep each image in a local cache
    NSImage *image = [icons objectForKey:name];
    if (image == nil) {
        image = [NSImage imageNamed:name];
        [icons setObject:image
                  forKey:name];
    }
    
    return image;
}

- (id)transformedValue:(id)value
{
    switch ([value integerValue]) {
        case FXROMAuditOK:
        case FXDriverComplete:
            return [self imageNamed:@"NSStatusAvailable"];
        case FXDriverPartial:
            return [self imageNamed:@"NSStatusPartiallyAvailable"];
        case FXROMAuditMissing:
        case FXDriverMissing:
            return [self imageNamed:@"NSStatusNone"];
        default:
        case FXROMAuditBadCRC:
        case FXROMAuditBadLength:
        case FXDriverUnplayable:
            return [self imageNamed:@"NSStatusUnavailable"];
    }
}

@end
