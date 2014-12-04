//
//  IFNoHighlighter.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

@class IFSyntaxData;

@interface IFNoHighlighter : NSObject<IFSyntaxHighlighter> {
	IFSyntaxData* activeData;					// Syntax data that we're using
}

@end
