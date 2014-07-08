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
#import "FXStatusAsNSImage.h"

#import "FXDriverAudit.h"

static NSMutableDictionary *icons;

@implementation FXStatusAsNSImage

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
        case FXDriverComplete:
            return [self imageNamed:@"NSStatusAvailable"];
        case FXDriverPartial:
            return [self imageNamed:@"NSStatusPartiallyAvailable"];
        case FXDriverMissing:
            return [self imageNamed:@"NSStatusNone"];
        default:
        case FXDriverUnplayable:
            return [self imageNamed:@"NSStatusUnavailable"];
    }
}

@end
