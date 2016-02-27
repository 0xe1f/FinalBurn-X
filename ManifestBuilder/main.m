//
//  main.m
//  ManifestBuilder
//
//  Created by Akop Karapetyan on 2/26/16.
//  Copyright © 2016 Akop Karapetyan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FXManifestBuilder.h"

int main(int argc, const char * argv[])
{
	if (argc < 2) {
		fprintf(stderr, "Usage: %s <output_path>\n", argv[0]);
		return 1;
	}
	
	@autoreleasepool {
		NSString *path = [NSString stringWithCString:argv[1]
											encoding:NSUTF8StringEncoding];
		
		FXManifestBuilder *builder = [[FXManifestBuilder alloc] init];
		[builder writeManifest:[NSURL fileURLWithPath:path]];
	}
	
    return 0;
}
