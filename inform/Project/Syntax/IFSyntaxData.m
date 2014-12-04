//
//  IFSyntaxData.m
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import "IFSyntaxData.h"
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

-(id) initWithTextView: (NSTextView*) view
                 range: (NSRange) range {
    self = [super init];
    if( self )
    {
        self.textView               = view;
        self.restrictedTextStorage  = [[[NSTextStorage alloc] init] autorelease];
        self.restrictedRange        = range;
    }
    return self;
}

@end

//
// Class holds the model for a text file currently being shown in a project. Each object owns
// the full text of a file, and up to two restricted versions (for the left/right hand panes of
// the project).
//
@implementation IFSyntaxData

@synthesize textStorage     = _textStorage;
@synthesize name            = _name;
@synthesize type            = _type;
@synthesize undoManager     = _undoManager;
@synthesize isHighlighting  = _isHighlighting;

-(id) initWithStorage: (NSTextStorage*) aStorage
                 name: (NSString*) aName
                 type: (IFHighlightType) aType
         intelligence: (id<IFSyntaxIntelligence,NSObject>) intelligence
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
        
        charStyles = NULL;
        lineStyles = [[NSMutableArray alloc] initWithObjects: [NSDictionary dictionary], nil];
        
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
        _restrictions = [[NSMutableArray alloc] init];

        // Are we currently syntax highlighting?
        _isHighlighting = false;
        
        // Initial state
        lineStarts[0] = 0;
        nLines = 1;
        [lineStates addObject:
            [NSMutableArray arrayWithObjects:
                [NSArray arrayWithObjects:
                    [NSNumber numberWithUnsignedInt: IFSyntaxStateDefault],
                    [NSNumber numberWithUnsignedInt: 0],
                 nil],
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

        int length = [_textStorage length];
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
    
    // Normal text sotrage
	[_textStorage release];

    // Restricted text storage
    [_restrictions release];

	[lineStates release];
	free(lineStarts);
	free(charStyles);
	[lineStyles release];
	
	[syntaxStack release];
    
	if (highlighter) {
		[highlighter setSyntaxData: nil];
		[highlighter release];
	}
	
	if (intelSource) {
		[intelSource setSyntaxData: nil];
		[intelSource release];
	}
	
	if (intelData) [intelData release];
	
	[paragraphStyles release];
	[tabStops release];
	
	[super dealloc];
}

// = Utility methods =

//
// Helper method.
// Which line of text does the character index occur on?
//
- (int) lineForIndex: (unsigned) index {
	// Yet Another Binary Search
	int low = 0;
	int high = nLines - 1;
	
	while (low <= high) {
		int middle = (low + high)>>1;
		
		unsigned lineStart = lineStarts[middle];

		if (index < lineStart) {
			// Not this line: search the lower half
			high = middle-1;
			continue;
		}

		unsigned lineEnd = middle<(nLines-1)?lineStarts[middle+1]:[_textStorage length];

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
- (IFSyntaxStyle) styleAtIndex: (unsigned) index
				effectiveRange: (NSRangePointer) range {
	IFSyntaxStyle style = charStyles[index];
	
	if (range) {
		NSRange localRange;								// Optimisation suggested by Shark
		const IFSyntaxStyle* localStyles = charStyles;	// Ditto
        
		localRange.location = index;
		localRange.length = 0;
		
		while (localRange.location > 0) {
			if (localStyles[localRange.location-1] == style) {
				localRange.location--;
			} else {
				break;
			}
		}
		
		unsigned strLen = [_textStorage length];
		
		while (localRange.location+localRange.length < strLen) {
			if (localStyles[localRange.location+localRange.length] == style) {
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
    
    int changeInLength = [attributedString length] - range.length;
    
    // If the change was made to one of the restricted storages, update the main text.
    bool foundChangeInRestrictedViews = false;
    for( IFSyntaxRestricted*restricted in _restrictions ) {
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
    for( IFSyntaxRestricted*restricted in _restrictions ) {
        // If this is the restricted storage that we want to change...
        if( [restricted restrictedTextStorage] == destinationStorage ) {
            NSRange restrictedRange = [restricted restrictedRange];
            
            // If the range of the edit lies (at least partially) within the restricted range
            // then we want to update the restricted text.
            if( ((range.location + range.length) > restrictedRange.location) &&
               (range.location < (restrictedRange.location + restrictedRange.length)) ) {
                
                // Normal edit range, in restricted storage
                int editStart = range.location - restrictedRange.location;
                int editEnd   = editStart + range.length;
                
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
    for( IFSyntaxRestricted*restricted in _restrictions ) {
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

// = Delegate methods =

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
- (void)textStorageWillProcessEditing:(NSNotification *)notification
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

    NSTextStorage *textStorage = [notification object];
    NSRange range = [textStorage editedRange];
    NSString *newString = [[textStorage string] substringWithRange:range];

	// Rewrite the change if needed (e.g. to auto-insert tabs when user presses return)
    editingRange = range;
    NSString* rewritten = [self rewriteInput: newString];
    if (rewritten) {
        // Actually make the change
        [textStorage replaceCharactersInRange: range
                                   withString: rewritten];

        // Make sure the undo manager knows how to undo this change
        if (self.undoManager) {
            [[self.undoManager prepareWithInvocationTarget: textStorage] replaceCharactersInRange: NSMakeRange(range.location, [rewritten length])
                                                                                       withString: newString];
        }

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
        changeInLength: (int) changeInLength {
    NSRange oldRange = NSMakeRange(newRange.location, newRange.length - changeInLength);

    // An edit consists of removing the oldRange of characters, then adding a newRange.
    
    // Work out what we need to remove
    int charactersToRemoveFromLocation = 0;
    int charactersToRemoveFromLength = 0;
    
    // Removing characters from before the start of the range changes the location
    if( oldRange.location < range.location ) {
        charactersToRemoveFromLocation = MIN(range.location - oldRange.location, oldRange.length);
    }
    
    // Removing characters within the range changes the length
    if( ((oldRange.location + oldRange.length) > range.location ) &&
         (oldRange.location <= (range.location + range.length)) ) {
        int start = MAX(oldRange.location - range.location, 0);
        int end   = MIN((oldRange.location + oldRange.length) - range.location, oldRange.location + oldRange.length);
        end       = MIN(end, range.length);
        
        charactersToRemoveFromLength = MAX(end - start, 0);
    }

    // Work out how much we need to add
    int charactersToAddToLocation = 0;
    int charactersToAddToLength = 0;

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
    int start = range.location;
    int end   = start + range.length;

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
-(void) textStorageDidProcessEditing: (NSNotification *)notification
{
    if( self.isHighlighting ) {
        return;
    }

    self.isHighlighting = true;

    NSTextStorage *textStorage  = [notification object];
    int changeInLength          = [textStorage changeInLength];
    NSRange newRange            = [textStorage editedRange];
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
        for( IFSyntaxRestricted*restricted in _restrictions ) {
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
    for( IFSyntaxRestricted*restricted in _restrictions ) {
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
                    changeInLength: (int) changeInLength
                   forceUpdateTabs: (bool) forceUpdateTabs {
    NSRange    oldRange  = NSMakeRange(newRange.location, newRange.length - changeInLength);
    NSString * newString = [[_textStorage string] substringWithRange:newRange];
    int newFullLength = [_textStorage length];
    int oldFullLength = newFullLength - changeInLength;

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
	unsigned* newLineStarts = NULL;
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
              [NSArray arrayWithObjects:
               [NSNumber numberWithUnsignedInt: IFSyntaxStateNotHighlighted],
               [NSNumber numberWithUnsignedInt: 0],
               nil]]];
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
	[newLineStates release];
	free(newLineStarts);
	newLineStarts = NULL;
	
	// Update the character styles of everything beyond our change
    int charactersToCopy = oldFullLength - oldRange.location - oldRange.length;
    if (changeInLength > 0) {
        // Move characters down (i.e. towards the back of the string)
        charStyles = realloc(charStyles, newFullLength);

        memmove(charStyles + newRange.location + newRange.length,
                charStyles + oldRange.location + oldRange.length,
                sizeof(*charStyles) * charactersToCopy);
    }
    else {
        // Move characters up (i.e. towards the front of the string)
        memmove(charStyles + newRange.location + newRange.length,
                charStyles + oldRange.location + oldRange.length,
                sizeof(*charStyles) * charactersToCopy);

        charStyles = realloc(charStyles, newFullLength);
    }

	// Characters in the edited range no longer have valid states
	for (x = 0; x < newRange.length; x++) {
		charStyles[x + newRange.location] = IFSyntaxStyleNotHighlighted;
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

    // No syntax highlighting
    if( ![[IFPreferences sharedPreferences] enableSyntaxHighlighting] ) {
        // Just use standard attributes
        [_textStorage addAttributes: [highlighter attributesForStyle: IFSyntaxNaturalInform]
                              range: range];
        return;
    }

    while( range.length > 0 ) {
        // What's the current style and it's range?
        style = [self styleAtIndex: range.location
                    effectiveRange: &styleRange];

        // Get the style attributes
        NSDictionary* styleAttributes = [highlighter attributesForStyle: style];
        [_textStorage addAttributes: styleAttributes
                              range: styleRange];

        NSAssert((styleRange.location + styleRange.length) <= [_textStorage length], @"Help!");
        
        int nextStart = styleRange.location + styleRange.length;
        int consumed  = nextStart - range.location;
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

// = Communication from the highlighter =

- (void) pushState {
    // When the highlighter opens a comment bracket (etc), it pushes the current state onto a stack.
	[syntaxStack addObject: [NSArray arrayWithObjects:
                             [NSNumber numberWithUnsignedInt: syntaxState],
                             [NSNumber numberWithUnsignedInt: syntaxMode],
                             nil]];
}

- (IFSyntaxState) popState {
    // When the highlighter closes a comment bracket (etc), it pops the state off the current stack.
	IFSyntaxState poppedState = [[[syntaxStack lastObject] objectAtIndex: 0] unsignedIntValue];
	syntaxMode = [[[syntaxStack lastObject] objectAtIndex: 1] unsignedIntValue];
	[syntaxStack removeLastObject];

	return poppedState;
}

- (void) backtrackWithStyle: (IFSyntaxStyle) newStyle
					 length: (int) backtrackLength {
	// Change the character style, going backwards for the specified length
	int x;
	
	for (x=syntaxPos-backtrackLength; x<syntaxPos; x++) {
		if (x >= 0) charStyles[x] = newStyle;
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
	
	int pos = syntaxPos-1-offset;
	NSString* str = [_textStorage string];

	// Skip whitespace
	while (pos > 0 && IsWhitespace([str characterAtIndex: pos]))
		pos--;
	
	// pos should now point at the last letter of the keyword (if it is the keyword)
	pos++;
	
	// See if the keyword is there
	int keywordLen = [keyword length];
	if (pos < keywordLen)
		return NO;

	NSString* substring = [str substringWithRange: NSMakeRange(pos-keywordLen, keywordLen)];

	return [substring caseInsensitiveCompare: keyword]==NSOrderedSame;
}


//
// = Actually performing highlighting =
//
// Phase One: Calculate charStyles, hint keywords, gather intelligence, indent paragraphs.
// Phase Two: Apply the character styles as attributes
// Phase Three: Add elastic tabs
//
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

	for (line=firstLine; line<=lastLine; line++) {
		// The range of characters in this line
		unsigned firstChar = lineStarts[line];
		unsigned  lastChar = (line+1) < nLines ? lineStarts[line+1] : [_textStorage length];
        
		// Set up the state
		[syntaxStack setArray: [lineStates objectAtIndex: line]];
        
		syntaxState = [[[syntaxStack lastObject] objectAtIndex: 0] unsignedIntValue];
		syntaxMode  = [[[syntaxStack lastObject] objectAtIndex: 1] unsignedIntValue];
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
			charStyles[syntaxPos] = nextStyle;
			
			// Store the state
			syntaxState = nextState;
		}

		// Provide an opportunity for the highlighter to hint keywords, etc
		NSString* lineToHint = [[_textStorage string] substringWithRange: NSMakeRange(firstChar, lastChar-firstChar)];
#if HighlighterDebug
		NSLog(@"Highlighter: finished line %i: '%@', rehinting", line, lineToHint);
#endif
		[highlighter rehintLine: lineToHint
						 styles: charStyles+firstChar
				   initialState: initialState];

		//
        // Gather intelligence for the line, if we have something to gather it with
        //
		if (intelSource && intelData) {
			[intelSource gatherIntelForLine: lineToHint
									 styles: charStyles+firstChar
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
                NSDictionary*       lastStyle		= [lineStyles objectAtIndex: line];
                NSParagraphStyle*   paraStyle		= [lastStyle objectForKey: NSParagraphStyleAttributeName];
                NSParagraphStyle*	newParaStyle	= [newStyle  objectForKey: NSParagraphStyleAttributeName];

                styleChanged = [paraStyle headIndent] != [newParaStyle headIndent];
                styleChanged |= forceUpdateTabs;

                if (styleChanged) {
                    // Update the dictionary for the new line style
                    NSMutableDictionary* newLineStyle = [[newStyle mutableCopy] autorelease];
                    [newLineStyle setObject: newParaStyle
                                     forKey: NSParagraphStyleAttributeName];
                    [lineStyles replaceObjectAtIndex: line
                                          withObject: newLineStyle];
                }
            }
        }

        if (styleChanged) {
            // Add the actual attributes for the paragraph indentation on the line
            [_textStorage addAttributes: newStyle
                                  range: NSMakeRange(firstChar, lastChar-firstChar)];
        }

		// Store the current state on the stack
		[syntaxStack addObject:
            [NSArray arrayWithObjects:
                [NSNumber numberWithUnsignedInt: syntaxState],
                [NSNumber numberWithUnsignedInt: syntaxMode],
                nil]];

		// Compare the new stack against the old version to see if anything has changed
		[previousOldStack release];
		previousOldStack = nil;
		if (line+1 < [lineStates count]) {
			previousOldStack = [[lineStates objectAtIndex: line+1] retain];

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
			[lineStates replaceObjectAtIndex: line+1
								  withObject: [[syntaxStack copy] autorelease]];
		}
	}

	// Clean up
	[previousOldStack release];
	[highlighter setSyntaxData: nil];

    //
    // Phase Two: Apply the character styles as attributes
    //
	unsigned firstRangeChar = lineStarts[firstLine];
	unsigned lastRangeChar = (lastLine+1) < nLines ? lineStarts[lastLine+1] : [_textStorage length];

    [self updateHighlightingForAttributedStringInRange: NSMakeRange(firstRangeChar, lastRangeChar-firstRangeChar)];

    //
    // Phase Three: Add elastic tabs
    //
    if ( [[IFPreferences sharedPreferences] elasticTabs] ) {
        for (line=firstLine; line<=lastLine; line++) {
            // The range of characters on the line
            unsigned firstChar = lineStarts[line];
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
				NSParagraphStyle* currentPara = [[lineStyles objectAtIndex: line] objectForKey: NSParagraphStyleAttributeName];

				// Lay out the tabs properly
				NSArray* newTabStops = [self elasticTabsInRegion: elasticRange];

				// Compare new tabs with the old ones...
				BOOL tabsIdentical = NO;
				if ([[currentPara tabStops] count] == [newTabStops count]) {
					tabsIdentical = YES;
					int x;
					for (x=0; x<[newTabStops count]; x++) {
						if (![[newTabStops objectAtIndex: x] isEqual: [[currentPara tabStops] objectAtIndex: x]]) {
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
						NSMutableDictionary*		style		= [[lineStyles objectAtIndex: formatLine] mutableCopy];
						NSMutableParagraphStyle*	paraStyle	= [[style objectForKey: NSParagraphStyleAttributeName] mutableCopy];
						if (!paraStyle) paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

						// Update the paragraph style with the new tabstops
						[paraStyle setTabStops: newTabStops];
						[style setObject: paraStyle forKey: NSParagraphStyleAttributeName];

						// Replace the line style
						[lineStyles replaceObjectAtIndex: formatLine
											  withObject: style];

						// Update tabs paragraph style for this line
						int formatFirstChar	= lineStarts[formatLine];
						int formatLastChar	= (formatLine+1<nLines)?lineStarts[formatLine+1]:[_textStorage length];

						[_textStorage addAttributes: style
                                              range: NSMakeRange(formatFirstChar, formatLastChar-formatFirstChar)];

						[style autorelease];
                        [paraStyle autorelease];
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

// = Notifications from the preferences object =

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
        [paragraphStyles release];
        paragraphStyles = nil;
        
        [tabStops release];
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


// = Tabbing =

- (NSArray*) standardTabStops {
	int x;

    // Set up member variable 'tabStops' - a standard set of tabs at the current width
	float stopWidth = [highlighter tabStopWidth];
	if (stopWidth < 1.0) stopWidth = 1.0;
	
	tabStops = [[NSMutableArray alloc] init];
	for (x=0; x<48; x++) {
		NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
												location: stopWidth*(x+1)];
		[tabStops addObject: tab];
		[tab release];
	}
    
	return tabStops;
}

- (NSDictionary*) generateParagraphStyleForTabStops: (int) numberOfTabStops {
    // Get the width of a tabstop
	float stopWidth = [highlighter tabStopWidth];
	if (stopWidth < 1.0) stopWidth = 1.0;

	NSMutableParagraphStyle* res = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];

	// Create standard tab stops if needed
	if (tabStops == nil) {
		[self standardTabStops];
	}

    // Set tabs
	[res setTabStops: tabStops];
	
    // Set head indent
	if ([[IFPreferences sharedPreferences] indentWrappedLines]) {
        // Indent half a tabstop width beyond the normal indent
        float headIndent = stopWidth * ((float) numberOfTabStops) + (stopWidth/2.0);

		[res setHeadIndent: headIndent];
		[res setFirstLineHeadIndent: 0];
	}

	return [NSDictionary dictionaryWithObject: res
									   forKey: NSParagraphStyleAttributeName];
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
		return [paragraphStyles objectAtIndex: numberOfTabStops];
	}
	
	// Generate missing tab stops if not
	int x;
	for (x=[paragraphStyles count]; x<=numberOfTabStops; x++) {
		[paragraphStyles addObject: [self generateParagraphStyleForTabStops: x]];
	}

	return [paragraphStyles objectAtIndex: numberOfTabStops];
}

// = Elastic tabs =

// See http://nickgravgaard.com/elastictabstops/ for more information on these

static inline BOOL IsLineEnd(unichar c) {
	return c == '\n' || c == '\r';
}

// Given a character index, returns the range of the line it is on
- (NSRange) lineRangeAtIndex: (int) charIndex {
	// Start and end of this line are initially the same
	int start	= charIndex;
	int end		= charIndex;
	
	NSString* text = [_textStorage string];
	
	// Move backwards to the beginning of the line
	start--;
	while (start >= 0 && !IsLineEnd([text characterAtIndex: start])) {
		start--;
	}
	
	// Move forwards to the end of the line
	int len = [text length];
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
	
	int chrPos;
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

	for (int chrPos = range.location; chrPos < range.location + range.length; chrPos++) {
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
- (NSRange) rangeOfElasticRegionAtIndex: (int) charIndex {
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
	int len = [_textStorage length];
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
	[currentLine release];
	
	int lastTabPos = region.location;
	int chrPos;
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
				numColumns = [currentLine count];
			}
			
			// Start the next column on the character after this one
			lastTabPos = chrPos + 1;
		}
        
		// Add a new line if necessary
		if (chr == '\n' || chr == '\r') {
			currentLine = [[NSMutableArray alloc] init];
			[lines addObject: currentLine];
			[currentLine release];
		}
	}
	
	// Work out the widths for each column
	float margin = 8.0;							// size of column margin
	
	NSMutableArray* elasticTabStops = [[[NSMutableArray alloc] init] autorelease];
	int colNum;
	for (colNum = 0; colNum < numColumns; colNum++) {
		[elasticTabStops addObject: [NSNumber numberWithFloat: [highlighter tabStopWidth]]];
	}
	
	for( NSArray* line in lines ) {
		for (colNum=0; colNum < [line count]; colNum++) {
			// Get the size of the line
			NSAttributedString* colString	= [line objectAtIndex: colNum];
			NSSize				thisSize	= [colString size];
			
			// Get the current width of this column
			float currentWidth = [[elasticTabStops objectAtIndex: colNum] floatValue];
			
			// Adjust as necessary
			if (thisSize.width + margin > currentWidth) {
				currentWidth = floorf(thisSize.width + margin);
				[elasticTabStops replaceObjectAtIndex: colNum
										   withObject: [NSNumber numberWithFloat: currentWidth]];
			}
		}
	}
	
	// Tab stops are currently widths: need to change them to NSTextTab objects locations
	float lastPosition = 0;
	for (colNum=0; colNum < numColumns; colNum++) {
		float currentValue	= [[elasticTabStops objectAtIndex: colNum] floatValue];
		float newValue		= floorf(currentValue + lastPosition);
		lastPosition = newValue;
		
		[elasticTabStops replaceObjectAtIndex: colNum
								   withObject: [[[NSTextTab alloc] initWithType: NSLeftTabStopType
																	   location: newValue] autorelease]];
	}
	
	// Done: no longer working out tab stops
	[lines release];
	computingElasticTabs = NO;
	
	// elasticTabStops now contains the set of tab stops for this region
	return elasticTabStops;
}

// = Gathering/retrieving intelligence data =

- (void) setIntelligence: (id<IFSyntaxIntelligence,NSObject>) intel {
    [intelData release];
	if (intelSource) {
		[intelSource setSyntaxData: nil];
		[intelSource release];
	}
	
	intelData = [[IFIntelFile alloc] init];
	intelSource = [intel retain];
	
	[intelSource setSyntaxData: self];
}

- (id<IFSyntaxIntelligence>) intelligence {
	return intelSource;
}

- (IFIntelFile*) intelligenceData {
	return intelData;
}

// = Intelligence callbacks =

- (int) editingLineNumber {
	return [self lineForIndex: editingRange.location];
}

- (int) numberOfTabStopsForLine: (int) lineNumber {
	// Details about the string
	int strLen = [_textStorage length];
	NSString* str = [_textStorage string];
    
	// Our current location, and the number of acquired tab stops
	int lineStart = lineStarts[lineNumber];
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
	int lineStart = lineStarts[lineNumber];
	int lineEnd = lineNumber+1<nLines?lineStarts[lineNumber+1]:[_textStorage length];
	
	return [[_textStorage string] substringWithRange: NSMakeRange(lineStart, lineEnd-lineStart)];
}

- (IFSyntaxStyle) styleAtStartOfLine: (int) lineNumber {
	return charStyles[lineStarts[lineNumber]];
}

- (IFSyntaxStyle) styleAtEndOfLine: (int) lineNumber {
	int pos = lineNumber+1 < nLines ? lineStarts[lineNumber+1]-1 : [_textStorage length]-1;
	
	if (pos < 0) return IFSyntaxStyleNotHighlighted;
	
	return charStyles[pos];
}

- (unichar) characterAtEndOfLine: (int) lineNumber {
    int pos;
    
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
										  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (void) replaceLine: (int) lineNumber
			withLine: (NSString*) newLine {
	if (lineNumber >= nLines) NSLog(@"Attempt to replace line %i (but we only have %i lines)", lineNumber, nLines);
    
	// Get the start/end of the line
	int lineStart = lineStarts[lineNumber];
	int lineEnd = lineNumber+1<nLines?lineStarts[lineNumber+1]:[_textStorage length];
	
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
    for( IFSyntaxRestricted* restricted in _restrictions ) {
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
        [_restrictions removeObject: restricted];
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
    [_restrictions addObject: restricted];
    [view.layoutManager replaceTextStorage: [restricted restrictedTextStorage]];
    [restricted release];

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
        NSAttributedString* attributedString = [[[NSAttributedString alloc] initWithString: @""] autorelease];
        [[restricted restrictedTextStorage] setAttributedString: attributedString];

        // Remove delegate
        [[restricted restrictedTextStorage] setDelegate: nil];

        // Remove from list of restrictions
        [_restrictions removeObject:restricted];
        
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
