//
//  IFInform6Highlighter.h
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

@class IFSyntaxData;

typedef union IFInform6State {
	struct IFInform6Outer {
		unsigned int comment:1;
		unsigned int singleQuote:1;
		unsigned int doubleQuote:1;
		unsigned int statement:1;
		unsigned int afterMarker:1;
		unsigned int highlight:1;
		unsigned int highlightAll:1;
		unsigned int colourBacktrack:1;
		unsigned int afterRestart:1;
		unsigned int waitingForDirective:1;	// Inverted!
		unsigned int dontKnowFlag:1;
		
		unsigned int backtrackColour: 5;
		unsigned int inner:16;
	} bitmap;
	
	unsigned int state;
} IFInform6State;

///
/// A syntax highlighter for Inform 6 files
/// (based on the Inform technical manual)
///
@interface IFInform6Highlighter : NSObject<IFSyntaxHighlighter>

@end
