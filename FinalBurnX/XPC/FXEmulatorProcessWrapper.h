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
#import <Cocoa/Cocoa.h>

#import "FXEmulationCommunication.h"

@class FXEmulatorProcessWrapper;

@protocol FXEmulatorEventDelegate<NSObject>

- (void) connectionDidEstablish:(FXEmulatorProcessWrapper *) wrapper;

@end

@interface FXEmulatorProcessWrapper : NSObject

@property (nonatomic, readonly) NSString *archive;
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) id<FXEmulationCommunication> remoteObjectProxy;

@property (nonatomic, weak) IBOutlet id<FXEmulatorEventDelegate> delegate;

- (void) setUpWithArchive:(NSString *) archive
					  uid:(NSString *) uid;
- (void) terminate;

@end
