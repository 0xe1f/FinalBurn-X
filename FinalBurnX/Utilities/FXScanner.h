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

#define FXSetStatusIncomplete 0
#define FXSetStatusComplete   1

#define FXFileStatusMissing 0
#define FXFileStatusInvalid 1
#define FXFileStatusValid   2

extern NSString *const kFXSetStatus;
extern NSString *const kFXSetFiles;
extern NSString *const kFXFileStatus;
extern NSString *const kFXFileLocation;
extern NSString *const kFXErrorMessage;

@protocol FXScannerDelegate <NSObject>

- (void) scanDidComplete:(NSDictionary *) result;
- (void) scanDidFail:(NSDictionary *) error;

@end

@interface FXScanner : NSObject

@property (nonatomic, strong) NSString *rootPath;
@property (nonatomic, strong) NSDictionary *sets;
@property (nonatomic, weak) IBOutlet id<FXScannerDelegate> delegate;

- (void) start;
- (void) stopAll;

@end
