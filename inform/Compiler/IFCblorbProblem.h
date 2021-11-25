//
//  IFCblorbProblem.h
//  Inform
//
//  Created by Andrew Hunter on 28/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFCompiler.h"

///
/// Class that deals with problems with the cblorb stage.
///
@interface IFCblorbProblem : NSObject<IFCompilerProblemHandler>

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithBuildDir: (NSString*) buildDir NS_DESIGNATED_INITIALIZER;

@end
