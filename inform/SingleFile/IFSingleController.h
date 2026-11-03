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
@interface IFSingleController : NSWindowController <NSMenuItemValidation>

-(instancetype) initWithInitialSelectionRange: (NSRange) initialRange;

- (void) indicateRange: (NSRange) rangeToHighlight;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;
- (void) setContinuousSpelling:(BOOL) continuousSpelling;

@end
