//
//  IFEmptyNaturalProject.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFProjectType.h"

//
// Project type that creates an empty Natural Inform project
//
// (Actually, we use the file and the current user name to generate an initial heading for the game)
//
@interface IFEmptyNaturalProject : NSObject<IFProjectType> {
    NSRange initialSelectionRange;
}

@end
