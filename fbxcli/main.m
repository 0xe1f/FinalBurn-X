//
//  main.m
//  fbxcli
//
//  Created by Akop Karapetyan on 10/30/16.
//  Copyright © 2016 Akop Karapetyan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FXManifestBuilder.h"

int main(int argc, const char * argv[])
{
	@autoreleasepool {
		FXManifestBuilder *builder = [[FXManifestBuilder alloc] init];
		NSDictionary *data = [builder romSets];
		
		[data writeToFile:@"/dev/stdout"
			   atomically:NO];
	}
    return 0;
}
