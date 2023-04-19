//
//  IFSyntaxData.m
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxData.h"
#import "IFSyntaxStyles.h"
#import "IFPreferences.h"
#import "IFNoHighlighter.h"
#import "IFInform6Highlighter.h"
#import "IFNaturalHighlighter.h"

#define HighlighterDebug 0

//
// Represents a restricted region of text. Used when viewing a limited section of Source.
//
@implementation IFSyntaxRestricted

@synthesize textView                = _textView;
@synthesize restrictedTextStorage   = _restrictedTextStorage;
@synthesize restrictedRange         = _restrictedRange;

- (instancetype) initWithTextView: (NSTextView*) view
                            range: (NSRange) range {
    self = [super init];
    if( self )
    {
        self.textView               = view;
        self.restrictedTextStorage  = [[NSTextStorage alloc] init];
        self.restrictedRange        = range;
    }
    return self;
}

@end

@implementation IFSyntaxData {

    // Restricted storage
    NSMutableArray*          restrictions;

    //
    // Syntax state - Line and character information
    //
    int				nLines;				// Number of lines
    NSUInteger*		lineStarts;			// Start positions of each line
    NSMutableArray* lineStates;			// Syntax stack at the start of lines

    IFSyntaxStyles* charStyles;			// Syntax state for each character
    NSMutableArray* lineStyles;			// NSParagraphStyles for each line

    //
    // Syntax state - current highlighter state
    //
    NSMutableArray*   syntaxStack;		// Current syntax stack
    NSUInteger		  syntaxPos;		// Current highlighter position
    IFSyntaxState     syntaxState;		// Active state
    IFHighlighterMode syntaxMode;		// 'Mode' - possible extra state from the highlighter

    //
    // The highlighter
    //
    id<IFSyntaxHighlighter,NSObject> highlighter;

    //
    // Paragraph styles
    //
    
    /// Tab stop array
    NSMutableArray*	tabStops;
    /// Maps number of tabs at the start of a line to the appropriate paragraph style
    NSMutableArray*	paragraphStyles;
    /// \c YES if we're currently computing elastic tab sizes
    BOOL			computingElasticTabs;

    //
    // 'Intelligence'
    //
    id<IFSyntaxIntelligence> intelSource;
    /// 'Intelligence' data
    IFIntelFile* intelData;
    
    /// Used while rewriting
    NSRange editingRange;
}

@synthesize textStorage     = _textStorage;
@synthesize name            = _name;
@synthesize type            = _type;
@synthesize undoManager     = _undoManager;
@synthesize isHighlighting  = _isHighlighting;

- (instancetype) initWithStorage: (NSTextStorage*) aStorage
                            name: (NSString*) aName
                            type: (IFHighlightType) aType
                    intelligence: (id<IFSyntaxIntelligence>) intelligence
                     undoManager: (NSUndoManager*) aUndoManager {
    self = [super init];

    if( self ) {
        self.textStorage = aStorage;
        self.name        = aName;
        self.type        = aType;
        self.undoManager = aUndoManager;

        // Setup variables for syntax highlighting
        lineStarts = malloc(sizeof(*lineStarts));
        lineStates = [[NSMutableArray alloc] init];
        
        charStyles = [[IFSyntaxStyles alloc] init];
        lineStyles = [[NSMutableArray alloc] initWithObjects: @{}, nil];
        
        syntaxStack = [[NSMutableArray alloc] init];
        syntaxPos = 0;
        
        switch( aType ) {
            case IFHighlightTypeInform6:
            {
                highlighter = [[IFInform6Highlighter alloc] init];
            }
            break;
            case IFHighlightTypeInform7:
            {
                highlighter = [[IFNaturalHighlighter alloc] init];
            }
            break;
            default:
            case IFHighlightTypeNone:
            {
                highlighter = nil;
            }
            break;
        }

        // Array of IFSyntaxRestricted storage (up to two)
        restrictions = [[NSMutableArray alloc] init];

        // Are we currently syntax highlighting?
        _isHighlighting = false;
        
        // Initial state
        lineStarts[0] = 0;
        nLines = 1;
        [lineStates addObject:
            [NSMutableArray arrayWithObjects:
                @[@(IFSyntaxStateDefault),
                    @0U],
             nil]]; // Initial stack starts with the default state

        // Set up default tabs
        [self paragraphStyleForTabStops: 8];

        // Set up intelligence
        [self setIntelligence: intelligence];

        // Set delegate to get notified about changes to the text
        [_textStorage setDelegate:self];

        // Syntax highlight the initial text
        [_textStorage beginEditing];
        self.isHighlighting = true;

        NSInteger length = [_textStorage length];
        [self updateAfterEditingRange: NSMakeRange(0, length)
                       changeInLength: length
                      forceUpdateTabs: true];

        self.isHighlighting = false;
        [_textStorage endEditing];

        // Register for preference change notifications
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(preferencesChanged:)
                                                     name: IFPreferencesEditingDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];
    }
    return self;
}

-(void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	free(lineStarts);
    if ((charStyles != NULL) && (charStyles.styles != NULL)) {
        free(charStyles.styles);
        charStyles.styles = NULL;
        charStyles.numCharStyles = 0;
    }

	if (highlighter) {
		[highlighter setSyntaxData: nil];
	}
	
	if (intelSource) {
		[intelSource setSyntaxData: nil];
	}
}

#pragma mark - Utility methods

//
// Helper method.
// Which line of text does the character index occur on?
//
- (int) lineForIndex: (NSUInteger) index {
	// Yet Another Binary Search
	int low = 0;
	int high = nLines - 1;
	
	while (low <= high) {
		int middle = (low + high)>>1;
		
		NSUInteger lineStart = lineStarts[middle];

		if (index < lineStart) {
			// Not this line: search the lower half
			high = middle-1;
			continue;
		}

		NSUInteger lineEnd = middle<(nLines-1)?lineStarts[middle+1]:(int) [_textStorage length];

		if (index >= lineEnd) {
			// Not this line: search the upper half
			low = middle+1;
			continue;
		}

		// Must be this line
		return middle;
	}

	// If we fell off, must be the last line (lines are unsigned, so we can't fall off the bottom)
	return nLines-1;
}

//
// Helper method.
// What's the current style and range at the given character index?
//
- (IFSyntaxStyle) styleAtIndex: (NSUInteger) index
				effectiveRange: (NSRangePointer) range {
    IFSyntaxStyle style = [charStyles read: index];
	
	if (range) {
		NSRange localRange;								// Optimisation suggested by Shark

		localRange.location = index;
		localRange.length = 0;
		
		while (localRange.location > 0) {
            if ([charStyles read:localRange.location-1] == style) {
				localRange.location--;
			} else {
				break;
			}
		}
		
		unsigned strLen = (int) [_textStorage length];
		
		while (localRange.location+localRange.length < strLen) {
            if ([charStyles read:localRange.location+localRange.length] == style) {
				localRange.length++;
			} else {
				break;
			}
		}
		
		*range = localRange;
	}
	
	return style;
}

//
// Copy the latest change from one textStorage into another
//
-(void) mirrorChangeInTextStorage: (NSTextStorage*) storage
                     replaceRange: (NSRange) range
             withAttributedString: (NSAttributedString*) attributedString
                    toTextStorage: (NSTextStorage*) destinationStorage {
    if( storage == destinationStorage ) {
        return;
    }
    
    int changeInLength = (int) [attributedString length] - (int) range.length;
    
    // If the change was made to one of the restricted storages, update the main text.
    bool foundChangeInRestrictedViews = false;
    for( IFSyntaxRestricted*restricted in restrictions ) {
        if( [restricted restrictedTextStorage] == storage ) {
            foundChangeInRestrictedViews = true;

            // Convert range to refer to full text
            range.location += [restricted restrictedRange].location;
            
            // Change the main text
            if( destinationStorage == _textStorage ) {
                [_textStorage replaceCharactersInRange: range
                                  withAttributedString: attributedString];
                return;
            }
            break;
        }
    }

    NSAssert(foundChangeInRestrictedViews || (storage == _textStorage), @"something not right with the text storage");

    // Change restricted view
    for( IFSyntaxRestricted*restricted in restrictions ) {
        // If this is the restricted storage that we want to change...
        if( [restricted restrictedTextStorage] == destinationStorage ) {
            NSRange restrictedRange = [restricted restrictedRange];
            
            // If the range of the edit lies (at least partially) within the restricted range
            // then we want to update the restricted text.
            if( ((range.location + range.length) > restrictedRange.location) &&
               (range.location < (restrictedRange.location + restrictedRange.length)) ) {
                
                // Normal edit range, in restricted storage
                int editStart = (int)range.location - (int)restrictedRange.location;
                int editEnd   = editStart + (int) range.length;
                
                // Clip within start of restricted storage
                if( editStart < 0 ) {
                    attributedString = [attributedString attributedSubstringFromRange: NSMakeRange(-editStart, [attributedString length] + editStart)];
                    changeInLength += editStart;
                    editStart = 0;
                }
                
                NSRange editRange = NSMakeRange(editStart, editEnd - editStart);
                
                // Change text
                [_textStorage replaceCharactersInRange: editRange
                                  withAttributedString: attributedString];
                
                // Restricted text range grows or shrinks with changes
                restrictedRange.length += changeInLength;
                [restricted setRestrictedRange:restrictedRange];
            }
            return;
        }
    }
}

//
// Duplicate the change just made in one storage through to all the other related textStorages
//
-(void) mirrorChangeInTextStorage: (NSTextStorage*) storage
                     replaceRange: (NSRange) range
             withAttributedString: (NSAttributedString*) attributedString {
    
    // Change main text
    [self mirrorChangeInTextStorage: storage
                       replaceRange: range
               withAttributedString: attributedString
                      toTextStorage: _textStorage];
    
    // Change all restricted views
    for( IFSyntaxRestricted*restricted in restrictions ) {
        [self mirrorChangeInTextStorage: storage
                           replaceRange: range
                   withAttributedString: attributedString
                          toTextStorage: [restricted restrictedTextStorage]];
    }
}

// Update the text to account for different line endings and intelligence changes
-(NSString*) rewriteInput:(NSString*) newString {
    NSString* result = newString;
    BOOL changed = NO;

    // Give intelligence a chance to rewrite the change
	if (intelSource && ([newString length] == 1) ) {
		result = [intelSource rewriteInput: newString];
        if( result == nil ) {
            result = newString;
        }
        else {
            changed = YES;
        }
    }

    // Normalize line endings
    if ([result rangeOfString:@"\r"].location != NSNotFound) {
        result = [result stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
        result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
        changed = YES;
    }
    
    if( changed ) {
        return result;
    }
    return nil;
}

#pragma mark - Delegate methods

//
// When the textView is *about to* accept a change (i.e. update it's text), this method can
// update the text first. We use it to (e.g.) insert tabs automatically when you press
// newline. This rewriting is calculated by the 'intelligence'.
//
// (See also the other main delegate method 'textStorageDidProcessEditing' below, which updates
// syntax highlighting and related text storages *after* a change has been made).
//
// A 'change' consists replacing one range of characters with another. A change is defined by
// an editedRange (this is the range of the *new* characters in the text) and a changeInLength
// (how many characters were added or taken away). A single change is effectively:
//      (a) first delete one range of characters, and then
//      (b) add a new different bunch of characters starting at the same location.
//
- (void)textStorage:(NSTextStorage *)textStorage
 willProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta
{
    if (self.isHighlighting) {
        return;
    }
    
    if (self.undoManager) {
       if ( ([self.undoManager isUndoing]) ||
            ([self.undoManager isRedoing]) ) {
        return;
       }
    }

    NSRange newRange = editedRange;
    NSString *newString = [[textStorage string] substringWithRange: newRange];

	// Rewrite the change if needed (e.g. to auto-insert tabs when user presses return)
    editingRange = newRange;
    NSString* rewritten = [self rewriteInput: newString];
    if (rewritten) {
        // Actually make the change
        [textStorage replaceCharactersInRange: newRange
                                   withString: rewritten];

        /*
         // Commented out:
         // We don't write the change to the other text storages here, as this will happen in textStorageDidProcessEditing
         //

        // Get attributed rewritten string
        NSAttributedString *attributedRewritten = [textStorage attributedSubstringFromRange: NSMakeRange(range.location, [rewritten length])];

        // Mirror the change into related text storages
        // The range has length zero here becuase the original change (before being rewritten) 
        // has not been reflected in the other storages, so we just need to insert the rewritten string
        [self mirrorChangeInTextStorage: textStorage
                           replaceRange: NSMakeRange(range.location, 0)
                   withAttributedString: attributedRewritten];
        */
    }
}

//
// Helper method.
// When a change occurs to the main text, a restricted range may well change position as a
// result. This method carefully calculates how to adjust the restricted range based on a
// change specified by the edited range and changeInLength.
//
-(NSRange) adjustRange: (NSRange) range
           editedRange: (NSRange) newRange
        changeInLength: (NSInteger) changeInLength {
    NSRange oldRange = NSMakeRange(newRange.location, newRange.length - changeInLength);

    // An edit consists of removing the oldRange of characters, then adding a newRange.
    
    // Work out what we need to remove
    NSUInteger charactersToRemoveFromLocation = 0;
    NSUInteger charactersToRemoveFromLength = 0;
    
    // Removing characters from before the start of the range changes the location
    if( oldRange.location < range.location ) {
        charactersToRemoveFromLocation = MIN(range.location - oldRange.location, oldRange.length);
    }
    
    // Removing characters within the range changes the length
    if( ((oldRange.location + oldRange.length) > range.location ) &&
         (oldRange.location <= (range.location + range.length)) ) {
        NSUInteger start = MAX(oldRange.location - range.location, 0);
        NSUInteger end   = MIN((oldRange.location + oldRange.length) - range.location, oldRange.location + oldRange.length);
        end       = MIN(end, range.length);
        
        charactersToRemoveFromLength = MAX(end - start, 0);
    }

    // Work out how much we need to add
    NSUInteger charactersToAddToLocation = 0;
    NSUInteger charactersToAddToLength = 0;

    // Adding characters before the range changes the location
    if( newRange.location < range.location ) {
        charactersToAddToLocation = newRange.length;
    }
    
    // Adding characters within the range changes the length
    if( (newRange.location >= range.location ) &&
        (newRange.location <= (range.location + range.length)) ) {
        charactersToAddToLength = MIN(newRange.location + newRange.length - range.location, newRange.length);
    }

    NSAssert(((int) range.location - charactersToRemoveFromLocation + charactersToAddToLocation) >= 0, @"Bad location for adjusting range");
    NSAssert(((int) range.length - charactersToRemoveFromLength + charactersToAddToLength) >= 0, @"Bad length for adjusting range");

    return NSMakeRange(range.location - charactersToRemoveFromLocation + charactersToAddToLocation,
                       range.length - charactersToRemoveFromLength + charactersToAddToLength);
}

//
// Helper method. Given an edited range within the full text and a restricted range, this
// carefully works out how much of the edit lies within that restricted range.
//
-(NSRange) intersectRange: (NSRange) range
      withRestrictedRange: (NSRange) restrictedRange
             didIntersect: (bool*) didIntersectOut {
    NSUInteger start = range.location;
    NSUInteger end   = start + range.length;

    // Clip the start and end to the restrictedRange
    if( start < restrictedRange.location ) {
        start = restrictedRange.location;
    }
    if( end > (restrictedRange.location + restrictedRange.length) ) {
        end = restrictedRange.location + restrictedRange.length;
    }

    // If we don't have a (start -> end) range left, there is no intersection
    if( start > end ) {
        *didIntersectOut = false;
        return NSMakeRange(NSNotFound, 0);
    }

    // If our new range has length > 0 and ends exactly at the start of the location,
    // this doesn't count as an intersection.
    if( (start < end) && end == (restrictedRange.location) ) {
        *didIntersectOut = false;
        return NSMakeRange(NSNotFound, 0);
    }

    *didIntersectOut = true;
    return NSMakeRange(start, end - start);
}

//
// Delegate method.
//
// When a change has occured to a text storage (whether it's to the main text or a restricted
// text) we want to keep all versions of the restricted and main text in sync.
//
// Therefore we:
//      (a) update the full text (if the change was to a restricted text),
//      (b) update the syntax highlighting on the full text
//      (c) copy the results into each of the restricted text storage(s).
//
// This process is quite fiddly, but it makes sure the different text storages are all in sync.
//
// A 'change' consists replacing one range of characters with another. A change is defined by
// an editedRange (this is the range of the *new* characters in the text) and a changeInLength
// (how many characters were added or taken away). A single change is effectively:
//      (a) first delete one range of characters, and then
//      (b) add a new different bunch of characters starting at the same location.
//
-(void) textStorage:(NSTextStorage *)textStorage
  didProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)changeInLength
{
    if( self.isHighlighting ) {
        return;
    }

    self.isHighlighting = true;

    NSRange newRange            = editedRange;
    NSRange oldRange            = NSMakeRange(newRange.location, newRange.length - changeInLength);

    // Start editing
    [_textStorage beginEditing];

    //
    // Mirror the change from a restricted storage into main text storage. This makes sure the
    // main text is up to date.
    //
    if( textStorage != _textStorage ) {
        NSAttributedString * newString  = [textStorage attributedSubstringFromRange: newRange];

        [self mirrorChangeInTextStorage: textStorage
                           replaceRange: oldRange
                   withAttributedString: newString
                          toTextStorage: _textStorage];

        // Convert local ranges to refer to full text
        for( IFSyntaxRestricted*restricted in restrictions ) {
            if( [restricted restrictedTextStorage] == textStorage ) {
                NSRange restrictedRange = [restricted restrictedRange];
                newRange.location += restrictedRange.location;
                oldRange.location += restrictedRange.location;
                break;
            }
        }
    }

    //
    // Update syntax highlighting on main text.
    //
    NSRange changedAttributesRange = [self updateAfterEditingRange: newRange
                                                    changeInLength: changeInLength
                                                   forceUpdateTabs: false];

    //
    // Copy changes from main text into each restricted text storage.
    // This copies not just the characters that have changed, but also the syntax highlighting
    // attributes too.
    //
    for( IFSyntaxRestricted*restricted in restrictions ) {
        // Adjust restricted range as appropriate to reflect the edit that's just occured
        // to the main text
        NSRange oldRestrictedRange = [restricted restrictedRange];
        NSRange newRestrictedRange = [self adjustRange: oldRestrictedRange
                                           editedRange: newRange
                                        changeInLength: changeInLength];
        [restricted setRestrictedRange:newRestrictedRange];

        // Start editing
        [[restricted restrictedTextStorage] beginEditing];
        
        //
        // Apply character changes
        //
        bool newIntersected;
        NSRange newIntersectRange;

        // If this restricted storage was not the one that has already updated...
        if( textStorage != [restricted restrictedTextStorage] ) {
            newIntersectRange = [self intersectRange: newRange
                                 withRestrictedRange: newRestrictedRange
                                        didIntersect: &newIntersected];
            bool oldIntersected;
            NSRange oldIntersectRange = [self intersectRange: oldRange
                                         withRestrictedRange: oldRestrictedRange
                                                didIntersect: &oldIntersected];
            if( oldIntersected && newIntersected ) {
                NSAttributedString* attributedString = [_textStorage attributedSubstringFromRange: newIntersectRange];
                NSRange localRange = NSMakeRange(oldIntersectRange.location - oldRestrictedRange.location, oldIntersectRange.length);
                [[restricted restrictedTextStorage] replaceCharactersInRange: localRange
                                                        withAttributedString: attributedString];
            }
        }

        //
        // Apply attribute changes
        //
        newIntersectRange = [self intersectRange: changedAttributesRange
                             withRestrictedRange: newRestrictedRange
                                    didIntersect: &newIntersected];
        if( newIntersected ) {
            NSRange localRange = NSMakeRange(newIntersectRange.location - newRestrictedRange.location, newIntersectRange.length);

            // Get the new attributed string
            NSAttributedString* attributedString = [_textStorage attributedSubstringFromRange: newIntersectRange];
            
            // Make sure we have got our calculations right and we are only changing attributes
            {
                NSString* oldText = [[[restricted restrictedTextStorage] string] substringWithRange:localRange];
                NSString* newText = [attributedString string];

                if( [newText isEqualToString:oldText] ) {
                    // Make the change
                    [[restricted restrictedTextStorage] replaceCharactersInRange: localRange
                                                            withAttributedString: attributedString];
                }
                else {
                    NSLog(@"Should be changing attributes only. Found oldText '%@' new Text '%@' differ", oldText, newText);
                    NSAssert(false, @"Should be changing attributes only");
                }
            }
        }

        // End editing
        [[restricted restrictedTextStorage] endEditing];
    }

    [_textStorage endEditing];
    
    self.isHighlighting = false;
}

//
// Given an update that has just occured to the main text storage, update it's syntax highlighting
//
-(NSRange) updateAfterEditingRange: (NSRange) newRange
                    changeInLength: (NSInteger) changeInLength
                   forceUpdateTabs: (bool) forceUpdateTabs {
    NSRange    oldRange  = NSMakeRange(newRange.location, newRange.length - changeInLength);
    NSString * newString = [[_textStorage string] substringWithRange:newRange];
    NSUInteger newFullLength = [_textStorage length];
    NSInteger oldFullLength = newFullLength - changeInLength;

	// The range of lines to be replaced
	int firstLine = [self lineForIndex: oldRange.location];
	int lastLine = [self lineForIndex: oldRange.location + oldRange.length];

#if HighlighterDebug
	NSLog(@"Highlighter: editing lines in the range %i-%i", firstLine, lastLine);
#endif

    //
	// Build the array of new lines.
    // Variables are:
    //      (a) newLineStarts - a malloc'd array holding the start character index of each line
    //      (b) newLineStates - an array of 'stacks' (one stack per line). Each 'stack' is a dictionary of the current highlighter state and inform6/7 'mode'.
    //
	NSUInteger* newLineStarts = NULL;
	int		  nNewLines = 0;
	NSMutableArray* newLineStates = [[NSMutableArray alloc] init];

	unsigned x;
	for (x=0; x<newRange.length; x++) {
		unichar thisChar = [newString characterAtIndex: x];
		
		if (thisChar == '\n' || thisChar == '\r') {
			nNewLines++;
			newLineStarts = realloc(newLineStarts, sizeof(*newLineStarts)*nNewLines);
			newLineStarts[nNewLines-1] = x + oldRange.location+1;
            
            [newLineStates addObject:
             [NSMutableArray arrayWithObject:
              @[@(IFSyntaxStateNotHighlighted),
               @0U]]];
		}
	}

    // Number of lines that have been added or taken away
	int lineDifference = ((int)nNewLines) - (int)(lastLine-firstLine);

#if HighlighterDebug
	NSLog(@"Highlighter: %i %@ lines (%i total)", lineDifference, nNewLines<(lastLine-firstLine)?@"new":@"removed",nLines);
#endif
	
	// Replace the line start positions (first line is still at the same position, with the same initial state, of course)
	if (nNewLines < (lastLine-firstLine)) {
		// Update first
		for (x=0; x<nNewLines; x++) {
			lineStarts[firstLine+1+x] = newLineStarts[x];
		}
		
		if (intelData) {
			// Remove the appropriate lines from the intelligence data
			[intelData removeLines: NSMakeRange(firstLine+1, -lineDifference)];
		}
		[lineStyles removeObjectsInRange: NSMakeRange(firstLine+1, -lineDifference)];
		
		// Move lines down
		memmove(lineStarts + firstLine + nNewLines + 1,
				lineStarts + lastLine + 1,
				sizeof(*lineStarts)*(nLines - (lastLine + 1)));
		lineStarts = realloc(lineStarts, sizeof(*lineStarts)*(nLines + lineDifference));
	} else {
		// Move lines up
		lineStarts = realloc(lineStarts, sizeof(*lineStarts)*(nLines + lineDifference));
		memmove(lineStarts + firstLine + nNewLines + 1,
				lineStarts + lastLine + 1,
				sizeof(*lineStarts)*(nLines - (lastLine + 1)));
        
		[lineStyles removeObjectsInRange: NSMakeRange(firstLine+1, lastLine-(firstLine))];
		if (intelData) [intelData removeLines: NSMakeRange(firstLine+1, lastLine-(firstLine))];
        
		// Update last
		for (x=0; x<nNewLines; x++) {
			[lineStyles insertObject: [self paragraphStyleForTabStops: 0]
							 atIndex: firstLine+1];
			if (intelData) [intelData insertLineBeforeLine: firstLine+1];
			
			lineStarts[firstLine+1+x] = newLineStarts[x];
		}
	}

    // Update the line states
	[lineStates replaceObjectsInRange: NSMakeRange(firstLine+1, lastLine-firstLine)
				 withObjectsFromArray: newLineStates];

	// Update the remaining line start positions
	nLines += lineDifference;
	
	for (x=firstLine + nNewLines+1; x<nLines; x++) {
		lineStarts[x] += changeInLength;
	}

	// Clean up data we don't need any more
	free(newLineStarts);
	newLineStarts = NULL;
	
	// Update the character styles of everything beyond our change
    NSInteger charactersToCopy = oldFullLength - oldRange.location - oldRange.length;
    if (changeInLength > 0) {
        // Move characters down (i.e. towards the back of the string)
        charStyles.styles = realloc(charStyles.styles, newFullLength);
        charStyles.numCharStyles = newFullLength;

        memmove(charStyles.styles + newRange.location + newRange.length,
                charStyles.styles + oldRange.location + oldRange.length,
                sizeof(*charStyles.styles) * charactersToCopy);
    }
    else {
        // Move characters up (i.e. towards the front of the string)
        memmove(charStyles.styles + newRange.location + newRange.length,
                charStyles.styles + oldRange.location + oldRange.length,
                sizeof(*charStyles.styles) * charactersToCopy);

        charStyles.styles = realloc(charStyles.styles, newFullLength);
        charStyles.numCharStyles = newFullLength;
    }

	// Characters in the edited range no longer have valid states
    NSAssert((newRange.length + newRange.location - 1) < charStyles.numCharStyles, @"index out of range");
	for (x = 0; x < newRange.length; x++) {
        [charStyles write:x + newRange.location value:IFSyntaxStyleNotHighlighted];
	}

	// Syntax highlight (up to) the rest of the text
    newRange.length = newFullLength - newRange.location;
	newRange = [self syntaxHighlightRange: newRange
                          forceUpdateTabs: forceUpdateTabs];
    return newRange;
}

//
// Update the attributes based on the new character styles for the range specified
//
-(void) updateHighlightingForAttributedStringInRange:(NSRange) range {
	// Get the basic style
	IFSyntaxStyle style;
	NSRange styleRange;
    
	if (!highlighter) {
        return;
    }

    // No syntax highlighting/colouring
    if(( ![[IFPreferences sharedPreferences] enableSyntaxHighlighting] ) &&
       ( ![[IFPreferences sharedPreferences] enableSyntaxColouring] )) {
        // Just use standard attributes
        [_textStorage setAttributes: [highlighter attributesForStyle: IFSyntaxNaturalInform]
                              range: range];
        [_textStorage fixFontAttributeInRange: range];
        return;
    }

    while( range.length > 0 ) {
        // What's the current style and it's range?
        style = [self styleAtIndex: range.location
                    effectiveRange: &styleRange];

        // Get the style attributes
        NSDictionary* styleAttributes = [highlighter attributesForStyle: style];
        [_textStorage setAttributes: styleAttributes range:styleRange];
        [_textStorage fixFontAttributeInRange: styleRange];

        NSAssert((styleRange.location + styleRange.length) <= [_textStorage length], @"Help!");
        
        NSUInteger nextStart = styleRange.location + styleRange.length;
        NSInteger consumed  = nextStart - range.location;
        range.location = nextStart;

        NSAssert(consumed >= 1, @"Consumed too little");

        range.length -= MIN(consumed, range.length);
    }

#if HighlighterDebug
    [_textStorage enumerateAttributesInRange:NSMakeRange(0, [_textStorage length])
                                     options:(NSAttributedStringEnumerationOptions)0
                                  usingBlock:^(NSDictionary* attrs, NSRange aRange, BOOL *stop) {
        //NSLog(@"attrs = %@ ***** range=%d length %d end=%d string length=%d *****",
        //      attrs, aRange.location, aRange.length, aRange.location + aRange.length, [self length]);

        NSAssert((aRange.location + aRange.length) <= [_textStorage length], @"Help!!!!");
    }];
#endif
}

#pragma mark - Communication from the highlighter

- (void) pushState {
    // When the highlighter opens a comment bracket (etc), it pushes the current state onto a stack.
	[syntaxStack addObject: @[@(syntaxState),
                             @(syntaxMode)]];
}

- (IFSyntaxState) popState {
    // When the highlighter closes a comment bracket (etc), it pops the state off the current stack.
	IFSyntaxState poppedState = [[syntaxStack lastObject][0] unsignedIntValue];
	syntaxMode = [[syntaxStack lastObject][1] unsignedIntValue];
	[syntaxStack removeLastObject];

	return poppedState;
}

- (void) backtrackWithStyle: (IFSyntaxStyle) newStyle
					 length: (int) backtrackLength {
	// Change the character style, going backwards for the specified length
	NSInteger x;

    NSAssert(syntaxPos < charStyles.numCharStyles, @"index out of range");
	for (x=syntaxPos-backtrackLength; x<syntaxPos; x++) {
        if (x >= 0) {
            [charStyles write:x value:newStyle];
        }
	}
}

- (void) setHighlighterMode: (IFHighlighterMode) newMode {
	// Sets the 'mode' of the highlighter (additional state info, basically)
	syntaxMode = newMode;
}

- (IFHighlighterMode) highlighterMode {
	// Retrieves the mode
	return syntaxMode;
}

static inline BOOL IsWhitespace(unichar c) {
	if (c == ' ' || c == '\t')
		return YES;
	else
		return NO;
}

- (BOOL) preceededByKeyword: (NSString*) keyword
					 offset: (int) offset {
	// If the given keyword preceeds the current position (case insensitively), this returns true
	if (syntaxPos == 0) return NO;
	
	NSInteger pos = syntaxPos-1-offset;
	NSString* str = [_textStorage string];

	// Skip whitespace
	while (pos > 0 && IsWhitespace([str characterAtIndex: pos]))
		pos--;
	
	// pos should now point at the last letter of the keyword (if it is the keyword)
	pos++;
	
	// See if the keyword is there
	NSInteger keywordLen = [keyword length];
	if (pos < keywordLen)
		return NO;

	NSString* substring = [str substringWithRange: NSMakeRange(pos-keywordLen, keywordLen)];

	return [substring caseInsensitiveCompare: keyword]==NSOrderedSame;
}


///
/// Actually performing highlighting
///
/// * Phase One: Calculate charStyles, hint keywords, gather intelligence, indent paragraphs.
/// * Phase Two: Apply the character styles as attributes.
/// * Phase Three: Add elastic tabs.
///
- (NSRange) syntaxHighlightRange: (NSRange) range
                 forceUpdateTabs: (bool) forceUpdateTabs {
    NSRange changedRange = range;

    //
	// The range of lines to be highlighted
    //
	int firstLine = [self lineForIndex: range.location];
	int lastLine = (range.length > 0) ? [self lineForIndex: range.location + range.length - 1] : firstLine;

#if HighlighterDebug
	NSLog(@"Highlighter: highlighting range %i-%i (lines %i-%i)", range.location, range.location + range.length, firstLine, lastLine);
#endif

	// Setup
	[highlighter setSyntaxData: self];

	// Perform the highlighting

    //
    // Phase One: Calculate charStyles, hint keywords, gather intelligence, indent paragraphs.
    //
	int line;
	NSArray* previousOldStack = nil; // The 'old' stack for the previous line
	NSRange previousElasticRange = NSMakeRange(NSNotFound, 0);	// The previous range formatted with elastic tabs
    IFSyntaxStyles* styles = [[IFSyntaxStyles alloc] init];

	for (line=firstLine; line<=lastLine; line++) {
		// The range of characters in this line
		NSUInteger firstChar = lineStarts[line];
		NSUInteger  lastChar = (line+1) < nLines ? lineStarts[line+1] : [_textStorage length];
        
		// Set up the state
		[syntaxStack setArray: lineStates[line]];
        
		syntaxState = [[syntaxStack lastObject][0] unsignedIntValue];
		syntaxMode  = [[syntaxStack lastObject][1] unsignedIntValue];
		[syntaxStack removeLastObject];

		IFSyntaxState initialState = syntaxState;
		
		// Number of tab stops (used for paragraph styles later)
		int numTabStops = 0;
		BOOL countingTabs = YES;

		// Highlight this line
		for (syntaxPos=firstChar; syntaxPos<lastChar; syntaxPos++) {
			// Current state
			unichar curChar = [[_textStorage string] characterAtIndex: syntaxPos];

			// Count tab stops at the start of the line
			if (countingTabs) {
				if (curChar == 9)
					numTabStops++;
				else
					countingTabs = NO;
			}

			// Next state
			IFSyntaxState nextState = [highlighter stateForCharacter: curChar
														  afterState: syntaxState];

			// Next style
			IFSyntaxStyle nextStyle = [highlighter styleForCharacter: curChar
														   nextState: nextState
														   lastState: syntaxState];

			// Store the style
            NSAssert(syntaxPos < charStyles.numCharStyles, @"index out of range");
			charStyles.styles[syntaxPos] = nextStyle;
			
			// Store the state
			syntaxState = nextState;
		}

		// Provide an opportunity for the highlighter to hint keywords, etc
		NSString* lineToHint = [[_textStorage string] substringWithRange: NSMakeRange(firstChar, lastChar-firstChar)];
#if HighlighterDebug
		NSLog(@"Highlighter: finished line %i: '%@', rehinting", line, lineToHint);
#endif
        styles.styles = charStyles.styles + firstChar;
        styles.numCharStyles = charStyles.numCharStyles - firstChar;
		[highlighter rehintLine: lineToHint
						 styles: styles
				   initialState: initialState];

		//
        // Gather intelligence for the line, if we have something to gather it with
        //
		if (intelSource && intelData) {
			[intelSource gatherIntelForLine: lineToHint
									 styles: styles
							   initialState: initialState
								 lineNumber: line
								   intoData: intelData];
		}

		// Add a paragraph indentation style based on the number of tab stops
        NSDictionary* newStyle	= [self paragraphStyleForTabStops: numTabStops];
        BOOL styleChanged = NO;

        if ([lineStyles count] <= line) {
            // Add a new style if it's needed for this line
            styleChanged = YES;
            for (;[lineStyles count] <= line;) {
                [lineStyles addObject: newStyle];
            }
        } else {
            // If we have not already laid this bit out using elastic tabs...
            if ( !NSLocationInRange(firstChar, previousElasticRange) ) {
                // Update the paragraph indentation style
                NSDictionary*       lastStyle		= lineStyles[line];
                NSParagraphStyle*   paraStyle		= lastStyle[NSParagraphStyleAttributeName];
                NSParagraphStyle*	newParaStyle	= newStyle[NSParagraphStyleAttributeName];

                styleChanged = [paraStyle headIndent] != [newParaStyle headIndent];
                styleChanged |= forceUpdateTabs;

                if (styleChanged) {
                    // Update the dictionary for the new line style
                    NSMutableDictionary* newLineStyle = [newStyle mutableCopy];
                    newLineStyle[NSParagraphStyleAttributeName] = newParaStyle;
                    lineStyles[line] = newLineStyle;
                }
            }
        }

        if (styleChanged) {
            // Add the actual attributes for the paragraph indentation on the line
            [_textStorage addAttributes: newStyle
                                  range: NSMakeRange(firstChar, lastChar-firstChar)];
            [_textStorage fixFontAttributeInRange: NSMakeRange(firstChar, lastChar-firstChar)];
        }

		// Store the current state on the stack
		[syntaxStack addObject:
            @[@(syntaxState),
                @(syntaxMode)]];

		// Compare the new stack against the old version to see if anything has changed
		previousOldStack = nil;
		if (line+1 < [lineStates count]) {
			previousOldStack = lineStates[line+1];

            //
            // Optimisation: If the state stack for the next line hasn't changed from what it
            // was previously, then we are done. (However, if we are reformatting due to a tab
            // setting change, then we can't optimise this way, we must format the entire rest
            // of the text).
            //
            if( !forceUpdateTabs ) {
                // If our state for the next line has not changed, then we are done syntax highlighting
                if ([previousOldStack isEqualToArray: syntaxStack]) {
                    lastLine = line;
                    break;
                }
            }
			lineStates[line+1] = [syntaxStack copy];
		}
	}

	// Clean up
	[highlighter setSyntaxData: nil];

    //
    // Phase Two: Apply the character styles as attributes
    //
	NSUInteger firstRangeChar = lineStarts[firstLine];
	NSUInteger lastRangeChar = (lastLine+1) < nLines ? lineStarts[lastLine+1] : [_textStorage length];

    [self updateHighlightingForAttributedStringInRange: NSMakeRange(firstRangeChar, lastRangeChar-firstRangeChar)];

    //
    // Phase Three: Add elastic tabs
    //
    if ( [[IFPreferences sharedPreferences] elasticTabs] ) {
        for (line=firstLine; line<=lastLine; line++) {
            // The range of characters on the line
            NSUInteger firstChar = lineStarts[line];
            //unsigned  lastChar = (line+1) < nLines ? lineStarts[line+1] : [_textStorage length];

			// Get the region affected by these elastic tabs
			NSRange elasticRange = [self rangeOfElasticRegionAtIndex: firstChar];

            // If we have an elastic range that we have not already dealt with...
			if (elasticRange.location != NSNotFound &&
                elasticRange.location != previousElasticRange.location
                && line < [lineStyles count]) {
				// This is now the last elastic range (prevents us from formatting the same region twice)
				previousElasticRange = elasticRange;

				// Fetch the current paragraph indentation style
				NSParagraphStyle* currentPara = lineStyles[line][NSParagraphStyleAttributeName];

				// Lay out the tabs properly
				NSArray* newTabStops = [self elasticTabsInRegion: elasticRange];

				// Compare new tabs with the old ones...
				BOOL tabsIdentical = NO;
				if ([[currentPara tabStops] count] == [newTabStops count]) {
					tabsIdentical = YES;
					int x;
					for (x=0; x<[newTabStops count]; x++) {
						if (![newTabStops[x] isEqual: [currentPara tabStops][x]]) {
							tabsIdentical = NO;
							break;
						}
					}
				}

                if( forceUpdateTabs ) {
                    tabsIdentical = NO;
                }

				// Update the tabs over this region if necessary
				if (!tabsIdentical) {
					int firstElasticLine	= [self lineForIndex: elasticRange.location];
					int lastElasticLine		= [self lineForIndex: elasticRange.location + elasticRange.length];
					if (elasticRange.location + elasticRange.length >= [_textStorage length]) lastElasticLine++;

					int formatLine;
					for (formatLine = firstElasticLine; formatLine < lastElasticLine; formatLine++) {
						while (formatLine >= [lineStyles count]) {
							// Create a default line style for this line
							[lineStyles addObject: [self paragraphStyleForTabStops: 0]];
						}

						// Copy the styles for this line
						NSMutableDictionary*		style		= [lineStyles[formatLine] mutableCopy];
						NSMutableParagraphStyle*	paraStyle	= [style[NSParagraphStyleAttributeName] mutableCopy];
						if (!paraStyle) paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

						// Update the paragraph style with the new tabstops
						[paraStyle setTabStops: newTabStops];
						style[NSParagraphStyleAttributeName] = paraStyle;

						// Replace the line style
						lineStyles[formatLine] = style;

						// Update tabs paragraph style for this line
						NSUInteger formatFirstChar	= lineStarts[formatLine];
						NSUInteger formatLastChar	= (formatLine+1<nLines)?lineStarts[formatLine+1]:[_textStorage length];

						[_textStorage addAttributes: style
                                              range: NSMakeRange(formatFirstChar, formatLastChar-formatFirstChar)];
                        [_textStorage fixFontAttributeInRange: NSMakeRange(formatFirstChar, formatLastChar-formatFirstChar)];
					}
				}
                
                // Record that we have changed this range of attributes
                changedRange = NSUnionRange(changedRange, elasticRange);
			}
		}
    }

    //
    // Return the range of all characters/attributes changed, including any elastic tabs that
    // were updated. We use this to copy the changes into restricted text storage.
    //
    return changedRange;
}

#pragma mark - Notifications from the preferences object

- (void) preferencesChanged: (NSNotification*) not {
    //
	// When the preferences have changed, force a re-highlight of everything
    //
	[self highlightAllForceUpdateTabs: true];
}

- (void) highlightAllForceUpdateTabs: (bool) forceUpdateTabs {
    
    // Set current state to highlighting
    bool oldIsHighlighting = self.isHighlighting;
    self.isHighlighting = true;
    
    // Flush out old indents / tabs if we force an update of tabs
    if( forceUpdateTabs ) {
        paragraphStyles = nil;
        
        tabStops = nil;
    }
    
    // Update highlighting for entire range
    [_textStorage beginEditing];
    
    [self syntaxHighlightRange: NSMakeRange(0, [_textStorage length])
               forceUpdateTabs: forceUpdateTabs];
    
    [_textStorage endEditing];

    // Restore old state
    self.isHighlighting = oldIsHighlighting;
}


#pragma mark - Tabbing

- (NSArray*) standardTabStops {
	int x;

    // Set up member variable 'tabStops' - a standard set of tabs at the current width
    CGFloat stopWidth = [highlighter tabStopWidth];
	if (stopWidth < 1.0) stopWidth = 1.0;
	
	tabStops = [[NSMutableArray alloc] init];
	for (x=0; x<48; x++) {
		NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
												location: stopWidth*(x+1)];
		[tabStops addObject: tab];
	}
    
	return tabStops;
}

- (NSDictionary*) generateParagraphStyleForTabStops: (int) numberOfTabStops {
    // Get the width of a tabstop
    //CGFloat stopWidth = [highlighter tabStopWidth];
	//if (stopWidth < 1.0) stopWidth = 1.0;

	NSMutableParagraphStyle* res = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	// Create standard tab stops if needed
	if (tabStops == nil) {
		[self standardTabStops];
	}

    // Set tabs
	[res setTabStops: tabStops];
	
    // Set head indent (no longer desired)
	//if ([[IFPreferences sharedPreferences] indentWrappedLines]) {
    //    // Indent half a tabstop width beyond the normal indent
    //    CGFloat headIndent = stopWidth * ((CGFloat) numberOfTabStops) + (stopWidth/2.0);

	//	[res setHeadIndent: headIndent];
	//	[res setFirstLineHeadIndent: 0];
	//}

	return @{NSParagraphStyleAttributeName: res};
}

- (NSDictionary*) paragraphStyleForTabStops: (int) numberOfTabStops {
	if (!paragraphStyles) {
		paragraphStyles = [[NSMutableArray alloc] init];
	}

    NSAssert(numberOfTabStops >= 0, @"Asking for a negative number of tabstops?! %d", numberOfTabStops);

	if (numberOfTabStops < 0) numberOfTabStops = 0;		// Technically an error
	if (numberOfTabStops > 48) numberOfTabStops = 48;	// Avoid eating all the pies^Wmemory

	// Use the cached version if available
	if (numberOfTabStops < [paragraphStyles count]) {
		return paragraphStyles[numberOfTabStops];
	}
	
	// Generate missing tab stops if not
	int x;
	for (x=(int)[paragraphStyles count]; x<=numberOfTabStops; x++) {
		[paragraphStyles addObject: [self generateParagraphStyleForTabStops: x]];
	}

	return paragraphStyles[numberOfTabStops];
}

#pragma mark - Elastic tabs

// See http://nickgravgaard.com/elastictabstops/ for more information on these

static inline BOOL IsLineEnd(unichar c) {
	return c == '\n' || c == '\r';
}

// Given a character index, returns the range of the line it is on
- (NSRange) lineRangeAtIndex: (NSUInteger) charIndex {
	// Start and end of this line are initially the same
	NSInteger start	= charIndex;
	NSInteger end	= charIndex;
	
	NSString* text = [_textStorage string];
	
	// Move backwards to the beginning of the line
	start--;
	while (start >= 0 && !IsLineEnd([text characterAtIndex: start])) {
		start--;
	}
	
	// Move forwards to the end of the line
	NSInteger len = [text length];
	unichar lastChr = '\0';
	while (end < len && !IsLineEnd(lastChr = [text characterAtIndex: end])) {
		end++;
	}
    
	// Include the line ending characters
	if (end+1 < len && lastChr == '\r' && [text characterAtIndex: end+1] == '\n') {
		end++;
	}
	
	if (end >= len) end = len-1;
	
	// Start now points to the newline preceeding this line, end to the final newline character, which we want to include in the result
	return NSMakeRange(start+1, end - start);
}

// Given a range, returns YES if it is blank (only whitespace)
- (BOOL) isBlank: (NSRange) range {
	NSString* text = [_textStorage string];
	
	NSUInteger chrPos;
	for (chrPos = range.location; chrPos < range.location + range.length; chrPos++) {
		unichar chr = [text characterAtIndex: chrPos];
		if (!IsWhitespace(chr) && !IsLineEnd(chr)) {
			return NO;
		}
	}
	
	return YES;
}

//
// Given a range, returns YES if it contains no tabs, or has a tab at the start (before any
// non-whitespace character).
//
- (BOOL) isTabLess: (NSRange) range {
	NSString* text = [_textStorage string];
	BOOL isBlank	= YES;

	for (NSUInteger chrPos = range.location; chrPos < range.location + range.length; chrPos++) {
		unichar chr = [text characterAtIndex: chrPos];
		if (chr == '\t') {
			// Don't apply elastic tabs to lines that already begin with a tab
			if (isBlank) return YES;
			return NO;
		}

		if (!IsWhitespace(chr) && !IsLineEnd(chr)) {
			isBlank = NO;
		}
	}

	return YES;
}

// Given a character index, work out the corresponding range where elastic tabs must apply
- (NSRange) rangeOfElasticRegionAtIndex: (NSUInteger) charIndex {
	// Hunt backwards for the beginning of the file, or the first blank line that preceeds this index
	NSRange firstLine	= [self lineRangeAtIndex: charIndex];
	NSRange lastLine	= firstLine;

	// Lines without tabs never use elastic tabs
	if ([self isTabLess: firstLine]) return NSMakeRange(NSNotFound, NSNotFound);

    // Look backwards through the lines, looking for the first one without tabs
	while (firstLine.location > 0) {
		// Get the range of the preceeding line
		NSRange previousLine = [self lineRangeAtIndex: firstLine.location - 1];

		// Give up if we've found a tabless line
		if ([self isTabLess: previousLine]) break;

		// Continue searching from this line
		firstLine = previousLine;
	}

	// Hunt forwards for the end of the file or the next tabless line that follows this index
	NSInteger len = [_textStorage length];
	while (lastLine.location + lastLine.length < len) {
		// Get the range of the following line
		NSRange nextLine = [self lineRangeAtIndex: lastLine.location + lastLine.length];

		// Give up if we've found a tabless line
		if ([self isTabLess: nextLine]) break;

		// Continue searching from this line
		lastLine = nextLine;
	}

	// If the first and last lines are different then this defines the region
	if (firstLine.location != lastLine.location) {
		return NSMakeRange(firstLine.location, (lastLine.location + lastLine.length) - firstLine.location);
	}

	// By default, elastic tabs do not apply to a character range
	return NSMakeRange(NSNotFound, NSNotFound);
}

// Given a character range, calculate the positions the 'elastic' tab stops should go at
- (NSArray*) elasticTabsInRegion: (NSRange) region {
	// Nothing to do if the region is 'not found'
	if (region.location == NSNotFound)	return [self standardTabStops];
	if (computingElasticTabs)			return [self standardTabStops];

	// Flag up that we're searching for tab stops to avoid possible re-entrancy issues
	computingElasticTabs = YES;
	
	// Get the text stored in this object
	NSString* text = [_textStorage string];
	
	// Now, chop up into lines and columns. Columns are separated by tabs.
	NSMutableArray* lines		= [[NSMutableArray alloc] init];
	NSMutableArray* currentLine	= [[NSMutableArray alloc] init];
	int numColumns = 0;
	
	[lines addObject: currentLine];
	
	NSInteger lastTabPos = region.location;
	NSUInteger chrPos;
	BOOL tabsAtStart = YES;
	for (chrPos = region.location; chrPos < region.location + region.length; chrPos++) {
		// Read the next character
		unichar chr = [text characterAtIndex: chrPos];
		
		// Skip the next character to deal with DOS line endings
		if (chr == '\r' && chrPos + 1 < region.location + region.length) {
			if ([text characterAtIndex: chrPos + 1] == '\n') {
				chrPos++;
			}
		}
		
		// Specify that we ignore tabs at the start of the line
		if (chr != '\t')				tabsAtStart = NO;
		if (chr == '\r' || chr == '\n')	tabsAtStart = YES;
		
		// If this is a newline or a tab, add a new column. We ignore tabs at the start of the line
		if ((chr == '\t' && !tabsAtStart) || chr == '\n' || chr == '\r' || (lastTabPos != chrPos && chrPos + 1 == region.location + region.length)) {
			// Store this column
			[currentLine addObject: [_textStorage attributedSubstringFromRange: NSMakeRange(lastTabPos, chrPos - lastTabPos)]];
			
			if ([currentLine count] > numColumns) {
				numColumns = (int) [currentLine count];
			}
			
			// Start the next column on the character after this one
			lastTabPos = chrPos + 1;
		}
        
		// Add a new line if necessary
		if (chr == '\n' || chr == '\r') {
			currentLine = [[NSMutableArray alloc] init];
			[lines addObject: currentLine];
		}
	}
	
	// Work out the widths for each column
    CGFloat margin = 8.0;							// size of column margin
	
	NSMutableArray* elasticTabStops = [[NSMutableArray alloc] init];
	int colNum;
	for (colNum = 0; colNum < numColumns; colNum++) {
		[elasticTabStops addObject: @([highlighter tabStopWidth])];
	}
	
	for( NSArray* line in lines ) {
		for (colNum=0; colNum < [line count]; colNum++) {
			// Get the size of the line
			NSAttributedString* colString	= line[colNum];
			NSSize				thisSize	= [colString size];
			
			// Get the current width of this column
            CGFloat currentWidth = [elasticTabStops[colNum] doubleValue];
			
			// Adjust as necessary
			if (thisSize.width + margin > currentWidth) {
				currentWidth = floor(thisSize.width + margin);
				elasticTabStops[colNum] = @(currentWidth);
			}
		}
	}
	
	// Tab stops are currently widths: need to change them to NSTextTab objects locations
    CGFloat lastPosition = 0;
	for (colNum=0; colNum < numColumns; colNum++) {
        CGFloat currentValue	= [elasticTabStops[colNum] doubleValue];
        CGFloat newValue		= floor(currentValue + lastPosition);
		lastPosition = newValue;
		
		elasticTabStops[colNum] = [[NSTextTab alloc] initWithType: NSLeftTabStopType
																	   location: newValue];
	}
	
	// Done: no longer working out tab stops
	computingElasticTabs = NO;
	
	// elasticTabStops now contains the set of tab stops for this region
	return elasticTabStops;
}

#pragma mark - Gathering/retrieving intelligence data

@synthesize intelligence = intelSource;

- (void) setIntelligence: (id<IFSyntaxIntelligence>) intel {
	if (intelSource) {
		[intelSource setSyntaxData: nil];
	}
	
	intelData = [[IFIntelFile alloc] init];
	intelSource = intel;
	
	[intelSource setSyntaxData: self];
}

@synthesize intelligenceData = intelData;

#pragma mark - Intelligence callbacks

- (int) editingLineNumber {
	return [self lineForIndex: editingRange.location];
}

- (int) numberOfTabStopsForLine: (int) lineNumber {
	// Details about the string
	NSInteger strLen = [_textStorage length];
	NSString* str = [_textStorage string];
    
	// Our current location, and the number of acquired tab stops
	NSInteger lineStart = lineStarts[lineNumber];
	int nTabStops = 0;
    
	while (lineStart < strLen && [str characterAtIndex: lineStart] == '\t') {
		lineStart++;
		nTabStops++;
	}
	
	return nTabStops;
}

- (NSString*) textForLine: (int) lineNumber {
	if (lineNumber >= nLines) return @"";
	
	// Get the start/end of the line
	NSInteger lineStart = lineStarts[lineNumber];
	NSInteger lineEnd = lineNumber+1<nLines?lineStarts[lineNumber+1]:[_textStorage length];
	
	return [[_textStorage string] substringWithRange: NSMakeRange(lineStart, lineEnd-lineStart)];
}

- (IFSyntaxStyle) styleAtStartOfLine: (int) lineNumber {
    return [charStyles read:lineStarts[lineNumber]];
}

- (IFSyntaxStyle) styleAtEndOfLine: (int) lineNumber {
	NSInteger pos = lineNumber+1 < nLines ? lineStarts[lineNumber+1]-1 : [_textStorage length]-1;
	
    if (pos < 0) return IFSyntaxStyleNotHighlighted;
    return [charStyles read:pos];
}

- (unichar) characterAtEndOfLine: (int) lineNumber {
    NSInteger pos;
    
    if( lineNumber+1 < nLines ) {
        // Move back -2 to skip the newline at the end of the previous line
        pos = lineStarts[lineNumber+1] - 2;
    }
    else {
        // Final character of the document
        pos = [_textStorage length] - 1;
    }

	if (pos < 0) return 0;
    if( [_textStorage length] < pos) return 0;
	
	return [[_textStorage string] characterAtIndex: pos];
}

- (void) callbackForEditing: (SEL) selector
				  withValue: (id) parameter {
	[[NSRunLoop currentRunLoop] performSelector: selector
										 target: intelSource
									   argument: parameter
										  order: 9
										  modes: @[NSDefaultRunLoopMode]];
}

- (void) replaceLine: (int) lineNumber
			withLine: (NSString*) newLine {
	if (lineNumber >= nLines) NSLog(@"Attempt to replace line %i (but we only have %i lines)", lineNumber, nLines);
    
	// Get the start/end of the line
	NSInteger lineStart = lineStarts[lineNumber];
	NSInteger lineEnd = lineNumber+1<nLines?lineStarts[lineNumber+1]:[_textStorage length];
	
	// Make sure the undo manager can undo this change
	if (self.undoManager) {
        [[self.undoManager prepareWithInvocationTarget: _textStorage] replaceCharactersInRange: NSMakeRange(lineStart, [newLine length])
                                                                                   withString: [[_textStorage string] substringWithRange: NSMakeRange(lineStart, lineEnd-lineStart)]];
	}

	// Perform the operation
	[_textStorage replaceCharactersInRange: NSMakeRange(lineStart, lineEnd-lineStart)
                                withString: newLine];
}

//
// Restricted text storage
//
-(IFSyntaxRestricted*) restrictedDataForTextView: (NSTextView*) view {
    for( IFSyntaxRestricted* restricted in restrictions ) {
        if( [restricted textView] == view ) {
            return restricted;
        }
    }
    return nil;
}

-(void) restrictToRange: (NSRange) range
            forTextView: (NSTextView *) view {
    // Get text for the given range
    NSAttributedString* attributedString = [_textStorage attributedSubstringFromRange: range];

    // Start editing the text
    _isHighlighting = true;
    
    // Remove old restricted region
    IFSyntaxRestricted* restricted = [self restrictedDataForTextView: view];
    if( restricted != nil ) {
        // Remove delegate
        [[restricted restrictedTextStorage] setDelegate: nil];
        [restrictions removeObject: restricted];
        restricted = nil;
    }

    // Create new restricted region
    restricted = [[IFSyntaxRestricted alloc] initWithTextView: view
                                                        range: range];

    // Set up the restricted text
    [restricted setRestrictedRange:range];
    [[restricted restrictedTextStorage]  setAttributedString: attributedString];

    // Add new text storage
    [[restricted restrictedTextStorage] setDelegate: self];
    [restrictions addObject: restricted];
    [view.layoutManager replaceTextStorage: [restricted restrictedTextStorage]];

    // Finish editing the text
    _isHighlighting = false;
}

-(void) removeRestrictionForTextView:(NSTextView*) view {
    // Find an existing restriction
    IFSyntaxRestricted* restricted = [self restrictedDataForTextView: view];

    if( restricted ) {
        // Start editing the text
        _isHighlighting = true;

        [restricted setRestrictedRange:NSMakeRange(NSNotFound, 0)];
        
        // Set restricted storage to an empty string
        NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString: @""];
        [[restricted restrictedTextStorage] setAttributedString: attributedString];

        // Remove delegate
        [[restricted restrictedTextStorage] setDelegate: nil];

        // Remove from list of restrictions
        [restrictions removeObject:restricted];
        
        // Finish editing the text
        _isHighlighting = false;
    }
}

-(BOOL) isRestrictedForTextView:(NSTextView*) view {
    // Find an existing restriction
    IFSyntaxRestricted* restricted = [self restrictedDataForTextView: view];
    return restricted != nil;
}

-(NSRange) restrictedRangeForTextView:(NSTextView*) view {
    // Find an existing restriction
    IFSyntaxRestricted* restricted = [self restrictedDataForTextView: view];
    if( restricted != nil ) {
        return [restricted restrictedRange];
    }
    return NSMakeRange(NSNotFound, 0);
}

-(NSTextStorage*) restrictedTextStorageForTextView:(NSTextView*) view {
    // Find an existing restriction
    IFSyntaxRestricted* restricted = [self restrictedDataForTextView: view];
    if( restricted != nil ) {
        return [restricted restrictedTextStorage];
    }
    return nil;
}

@end
