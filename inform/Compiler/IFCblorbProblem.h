//
//  IFCblorbProblem.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 28/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFCompiler.h"

///
/// Class that deals with problems with the cblorb stage.
///
@interface IFCblorbProblem : NSObject<IFCompilerProblemHandler> {
	NSString* buildDir;									// nil, or the build directory that should be inspected for problem files
}

- (id) initWithBuildDir: (NSString*) buildDir;

@end
