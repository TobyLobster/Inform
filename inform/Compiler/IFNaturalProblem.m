//
//  IFNaturalProblem.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFNaturalProblem.h"


@implementation IFNaturalProblem

- (NSURL*) urlForProblemWithErrorCode: (int) errorCode {
	if (errorCode == 0) return nil;						// Compiler succeeded
	if (errorCode == 1) return nil;						// Code 1 indicates a 'normal' failure
	if (errorCode < 0) return nil;						// We ignore negative return codes should they occur
	
	// Default error page is Error0
	NSString* fileURLString = @"inform:/Error0.html";
	
	// See if we've got a file for this specific error code
	NSString* specificFile = [NSString stringWithFormat: @"Error%i", errorCode];
	NSString* resourcePath = [[NSBundle mainBundle] pathForResource: specificFile
															 ofType: @"html"];
	
	if (resourcePath != nil && [[NSFileManager defaultManager] fileExistsAtPath: resourcePath]) {
		fileURLString = [NSString stringWithFormat: @"inform:/%@.html", specificFile];
	}
	
	// Return the result
	return [NSURL URLWithString: fileURLString];
}

@end
