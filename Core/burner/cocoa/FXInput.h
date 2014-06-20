//
//  FXInput.h
//  FinalBurnX
//
//  Created by Akop Karapetyan on 6/18/14.
//  Copyright (c) 2014 Akop Karapetyan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AKKeyboardManager.h"

@interface FXInput : NSObject<AKKeyboardEventDelegate>
{
    BOOL hasFocus;
    BOOL keyStates[256];
}

- (void)setFocus:(BOOL)focus;

@end
