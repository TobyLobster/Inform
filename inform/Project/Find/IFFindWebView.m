//
//  IFFindWebView.m
//  Inform
//
//  Created by Andrew Hunter on 23/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFFindWebView.h"


@implementation WebView(IFFindWebView)

#pragma mark - Basic interface

- (BOOL) findNextMatch:	(NSString*) match
				ofType: (IFFindType) type {
	BOOL insensitive = (type&IFFindCaseInsensitive)!=0;

	if (![self searchFor: match
				 direction: YES
			 caseSensitive: !insensitive
					wrap: YES]) {
		NSBeep();
		return NO;
	} else {
		return YES;
	}
}

- (BOOL) findPreviousMatch: (NSString*) match
					ofType: (IFFindType) type {
	BOOL insensitive = (type&IFFindCaseInsensitive)!=0;
	
	if (![self searchFor: match
				 direction: NO
			 caseSensitive: !insensitive
					wrap: YES]) {
		NSBeep();
		return NO;
	} else {
		return YES;
	}
}

- (BOOL) canUseFindType: (IFFindType) find {
	switch (find) {
		case IFFindContains:
			return YES;
			
		case IFFindBeginsWith:
		case IFFindCompleteWord:
		case IFFindRegexp:
		default:
			return NO;
	}
}

- (NSString*) currentSelectionForFind {
	return [[self selectedDOMRange] toString];
}

#pragma mark - 'Find all'

/*
- (NSArray*) findAllMatches: (NSString*) match
					 ofType: (IFFindType) type
                 inLocation: (IFFindLocation) location
		   inFindController: (IFFindController*) controller
			 withIdentifier: (id) identifier {
}

- (void) highlightFindResult: (IFFindResult*) result {
}
*/

@end
