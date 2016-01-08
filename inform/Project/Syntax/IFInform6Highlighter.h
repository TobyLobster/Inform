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

union IFInform6State {
	struct IFInform6Outer {
		int comment:1;
		int singleQuote:1;
		int doubleQuote:1;
		int statement:1;
		int afterMarker:1;
		int highlight:1;
		int highlightAll:1;
		int colourBacktrack:1;
		int afterRestart:1;
		int waitingForDirective:1;	// Inverted!
		int dontKnowFlag:1;
		
		unsigned int backtrackColour: 5;
		unsigned int inner:16;
	} bitmap;
	
	unsigned int state;
};

typedef union IFInform6State IFInform6State;

//
// A syntax highlighter for Inform 6 files
// (based on the Inform technical manual)
//
@interface IFInform6Highlighter : NSObject<IFSyntaxHighlighter>

@end
