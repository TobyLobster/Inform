//
//  IFSingleController.h
//  Inform
//
//  Created by Andrew Hunter on 25/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSourceSharedActions.h"

///
/// WindowController for a single-file document.
///
@interface IFSingleController : NSWindowController

-(instancetype) initWithInitialSelectionRange: (NSRange) initialRange NS_DESIGNATED_INITIALIZER;

- (void) indicateRange: (NSRange) rangeToHighlight;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;
- (void) setContinuousSpelling:(BOOL) continuousSpelling;

@end
