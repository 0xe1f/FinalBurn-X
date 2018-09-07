/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/0xe1f/FinalBurn-X
 ** Copyright (C) 2014-2018 Akop Karapetyan
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

@protocol FXVideoDelegate<NSObject>

@optional
- (void)screenSizeDidChange:(NSSize)newSize;
- (void)initTextureOfWidth:(int)width
                    height:(int)height
                 isRotated:(BOOL)rotated
             bytesPerPixel:(int)bytesPerPixel;
- (void)renderFrame:(unsigned char *)bitmap;

@end

@interface FXVideo : NSObject

@property (nonatomic, weak) id<FXVideoDelegate> delegate;

@end
