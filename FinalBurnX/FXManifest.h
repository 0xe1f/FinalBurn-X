/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014-2016 Akop Karapetyan
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
#import <Foundation/Foundation.h>

@class FXDriverAudit; // FIXME!

@interface FXButton : NSObject

@property (nonatomic, assign) int code;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *title;

@end

@interface FXDriver : NSObject

@property (nonatomic, readonly) int index;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *system;
@property (nonatomic, readonly) NSSize screenSize;
@property (nonatomic, readonly) FXDriver *parent;
@property (nonatomic, readonly) NSArray<FXDriver *> *children;
@property (nonatomic, readonly) NSArray<FXButton *> *buttons;

// FIXME
@property (nonatomic, strong) FXDriverAudit *audit;

@end

@interface FXManifest : NSObject

+ (FXManifest *) sharedInstance;
- (FXDriver *) driverNamed:(NSString *) name;

@property (nonatomic, readonly) NSArray<FXDriver *> *drivers;

@end
