//
//  IFSingleController.h
//  Inform
//
//  Created by Andrew Hunter on 25/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFSourceSharedActions.h"
#import "IFProjectTypes.h"

NS_ASSUME_NONNULL_BEGIN

///
/// WindowController for a single-file document.
///
@interface IFSingleController : NSWindowController <NSMenuItemValidation>

-(instancetype) initWithInitialSelectionRange: (NSRange) initialRange;

- (void) indicateRange: (NSRange) rangeToHighlight;

/// Selects and shows a line of the file. The project controller asks this of a file's windows for a line in
/// that file, when the file is open on its own.
- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file
                           style: (IFLineStyle) style;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;

@end

NS_ASSUME_NONNULL_END
