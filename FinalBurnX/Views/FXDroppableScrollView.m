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
#import "FXDroppableScrollView.h"

@implementation FXDroppableScrollView

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]) != nil) {
        [self registerForDraggedTypes:@[NSFilenamesPboardType]];
    }
    
    return self;
}

#pragma mark - Drag & Drop

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    return [[pboard types] containsObject:NSFilenamesPboardType];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *paths = [pboard propertyListForType:NSFilenamesPboardType];
    
    [[self scanner] importArchives:paths];
    
    return YES;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    __block NSDragOperation dragOp = NSDragOperationNone;
    
    if ([sender draggingSourceOperationMask] & NSDragOperationCopy) {
        NSPasteboard *pboard = [sender draggingPasteboard];
        if ([[pboard types] containsObject:NSFilenamesPboardType]) {
            NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
            if ([files count] > 0) {
                dragOp = NSDragOperationCopy;
                [files enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
                    if (![[self scanner] isArchiveSupported:path]) {
                        dragOp = NSDragOperationNone;
                        *stop = YES;
                    }
                }];
            }
        }
    }
    
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
}

@end
