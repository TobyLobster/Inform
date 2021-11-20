//
//  IFIsWatch.h
//  Inform
//
//  Created by Andrew Hunter on 11/12/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFInspector.h"

/// The inspector key for this window
extern NSString* const IFIsWatchInspector;

// 'Special' evaluation values
enum {
	IFEvalError  = 0xffffffff,
	IFEvalNoGame = 0xfffffffe
};

///
/// Inspector that provides the interface to watch or evaluate expressions
///
/// Unlike 'real' debuggers, Zoom can't break on watchpoints without seriously sacrificing performance, so
/// we don't do that.
///
@interface IFIsWatch : IFInspector

/// The shared watch inspector
+ (IFIsWatch*) sharedIFIsWatch;

/// Called when the quick watch expression has changed to a new value
- (IBAction) expressionChanged: (id) sender;

/// Returns the integer result of evaluating an Inform expression
- (unsigned) evaluateExpression: (NSString*) expression;
/// Refreshes the expressions displayed in the watch table
- (void) refreshExpressions;

@end
