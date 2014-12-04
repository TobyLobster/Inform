//
//  IFDiff.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 19/05/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// Class to produce the shortest edit script between two arrays
//
// Algorithm based on the original diff algorithm
//
@interface IFDiff : NSObject {
	// The arrays we are comparing
	NSArray* sourceArray;
	NSArray* destArray;
}

// Initialisation
- (id) initWithSourceArray: (NSArray*) sourceArray
		  destinationArray: (NSArray*) destArray;

// Performing the comparison (returns an array of IFDiffSteps)
- (NSArray*) compareArrays;

@end
