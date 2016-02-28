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

#import "FXManifestBuilder.h"

int main(int argc, const char * argv[])
{
	if (argc < 3) {
		fprintf(stderr, "Usage: %s <set_manifest_path> <component_manifest_path>\n", argv[0]);
		return 1;
	}
	
	@autoreleasepool {
		NSString *setPath = [NSString stringWithCString:argv[1]
											   encoding:NSUTF8StringEncoding];
		NSString *componentPath = [NSString stringWithCString:argv[2]
													 encoding:NSUTF8StringEncoding];
		
		FXManifestBuilder *builder = [[FXManifestBuilder alloc] init];
		[builder writeManifests:[NSURL fileURLWithPath:setPath]
				  componentPath:[NSURL fileURLWithPath:componentPath]];
	}
	
    return 0;
}
