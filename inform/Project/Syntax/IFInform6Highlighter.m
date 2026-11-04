//
//  IFInform6Highlighter.m
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFInform6Highlighter.h"
#import "IFSyntaxData.h"
#import "IFSyntaxStyles.h"
#import "IFProjectPane.h"

@implementation IFInform6Highlighter {
    IFSyntaxData* activeData;
}

#pragma mark - The statemachine itself

static inline BOOL IsIdentifier(int chr) {
    if (isalpha(chr) || isdigit(chr) || chr == '$' || chr == '#' || chr == '_') {
        return YES;
    } else {
        return NO;
    }
}

// We use cStrings instead for speed reasons (NSSets are very slow for the amount of
// lookups we need to do)
static int    numCodeKeywords = 0;
static char** codeKeywords = NULL;
static int    numOtherKeywords = 0;
static char** otherKeywords = NULL;

static NSSet* codeKwSet;
static NSSet* otherKwSet;

static inline BOOL FindKeyword(char** keywordList, int nKeywords, char* keyword) {	
    int bottom = 0;
    int top = nKeywords-1;
    
    int pos;
	
	int x;
	for (x=0; keyword[x] != 0; x++) {
		keyword[x] = tolower(keyword[x]);
	}
    
    while (top > bottom) {
        pos = (top+bottom)>>1;
        
        int cmp = strcmp(keywordList[pos], keyword);
        
        if (cmp == 0) return YES;
        if (cmp < 0) bottom = pos+1;
        if (cmp > 0) top = pos-1;
    }
    
    if (top == bottom && strcmp(keywordList[top], keyword) == 0) return YES;
    
    return NO;
}

- (BOOL) innerStateMachine: (IFInform6State*) state
                 character: (int) chr {
    BOOL terminalFlag = NO;
    
    //chr = tolower(chr);
    if (state->bitmap.inner >= 0x8000) {
        state->bitmap.inner = 0;
    }
    
    if (state->bitmap.inner == 0) {
        switch (chr) {
            case '-':
                state->bitmap.inner = 1;
                break;
            case '*':
                state->bitmap.inner = 3;
                terminalFlag = YES;
                break;
            case ' ': case '\t': case '#': case '\n': case '\r':
                state->bitmap.inner = 0;
                break;
            case '_':
                state->bitmap.inner = 0x100;
                break;
            case 'w':
                state->bitmap.inner = 0x101;
                break;
            case 'h':
                state->bitmap.inner = 0x111;
                break;
            case 'c':
                state->bitmap.inner = 0x121;
                break;
            default:
                if (isalpha(chr)) state->bitmap.inner = 0x100; else state->bitmap.inner = 0xff;
        }
    } else if (state->bitmap.inner == 1) {
        if (chr == '>') {
            state->bitmap.inner = 2;
            terminalFlag = YES;
        } else {
            state->bitmap.inner = 0xff;
        }
    } else if (state->bitmap.inner == 2) {
        state->bitmap.inner = 0;
    } else if (state->bitmap.inner == 3) {
        state->bitmap.inner = 0;
    } else if (state->bitmap.inner == 0xff) {
        if (chr == ' ' || chr == '\t' || chr == '\n' || chr == '\r') {
            state->bitmap.inner = 0;
        } else {
            state->bitmap.inner = 0xff;
        }
    } else if (state->bitmap.inner >= 0x100 && state->bitmap.inner < 0x8000) {
        if (!(isalpha(chr) || isdigit(chr) || chr == '_')) {
            state->bitmap.inner += 0x8000;
            terminalFlag = YES;
        }        
		
        switch (state->bitmap.inner) {
            case 0x101:
                if (chr == 'i')
                    state->bitmap.inner = 0x202;
                else
                    state->bitmap.inner = 0x200;
                break;
            case 0x202:
                if (chr == 't')
                    state->bitmap.inner = 0x303;
                else
                    state->bitmap.inner = 0x300;
                break;
            case 0x303:
                if (chr == 'h')
                    state->bitmap.inner = 0x404;
                else
                    state->bitmap.inner = 0x400;
                break;
            case 0x111:
                if (chr == 'a')
                    state->bitmap.inner = 0x212;
                else
                    state->bitmap.inner = 0x200;
                break;
            case 0x212:
                if (chr == 's')
                    state->bitmap.inner = 0x313;
                else
                    state->bitmap.inner = 0x300;
                break;
            case 0x121:
                if (chr == 'l')
                    state->bitmap.inner = 0x222;
                else
                    state->bitmap.inner = 0x200;
                break;
            case 0x222:
                if (chr == 'a')
                    state->bitmap.inner = 0x323;
                else
                    state->bitmap.inner = 0x300;
                break;
            case 0x323:
                if (chr == 's')
                    state->bitmap.inner = 0x424;
                else
                    state->bitmap.inner = 0x400;
                break;
            case 0x424:
                if (chr == 's')
                    state->bitmap.inner = 0x525;
                else
                    state->bitmap.inner = 0x500;
                break;
                
            default:
                if (isalpha(chr) || isdigit(chr) || chr == '_') {
                    state->bitmap.inner += 0x100;
                }
                break;
        }
    } else if (state->bitmap.inner >= 0x8000) {
		state->bitmap.inner = 0;
	}
    
    return terminalFlag;
}

- (IFInform6State) nextState: (IFInform6State) state
               nextCharacter: (int) chr {
    IFInform6State newState = state;
    
    // 1.  Is the comment bit set?
    //        Is the character a new-line?
    //           If so, clear the comment bit.
    //           Stop.
	
    if (state.bitmap.comment) {
        if (chr == '\n' || chr == '\r') {
            newState.bitmap.comment = 0;
        }
        return newState;
    }
    
    // 2.  Is the double-quote bit set?
    //        Is the character a double-quote?
    //           If so, clear the double-quote bit.
    //           Stop.
    
    if (state.bitmap.doubleQuote) {
        if (chr == '"') {
            newState.bitmap.doubleQuote = 0;
        }
        return newState;
    }
    
    // 3.  Is the single-quote bit set?
    //        Is the character a single-quote?
    //           If so, clear the single-quote bit.
    //           Stop.
    
    if (state.bitmap.singleQuote) {
        if (chr == '\'') {
            newState.bitmap.singleQuote = 0;
        }
        return newState;
    }
    
    // 4.  Is the character a single quote?
    //        If so, set the single-quote bit and stop.
    
    if (chr == '\'') {
        newState.bitmap.singleQuote = 1;
        return newState;
    }
    
    // 5.  Is the character a double quote?
    //        If so, set the double-quote bit and stop.
    
    if (chr == '"') {
        newState.bitmap.doubleQuote = 1;
        return newState;
    }
    
    // 6.  Is the character an exclamation mark?
    //        If so, set the comment bit and stop.
    
    if (chr == '!') {
        newState.bitmap.comment = 1;
        return newState;
    }
    
    // 7.  Is the statement bit set?
    if (state.bitmap.statement) {
        //        If so:
        //           Is the character "]"?
        //              If so:
        //                 Clear the statement bit.
        //                 Stop.
        
        if (chr == ']') {
            newState.bitmap.statement = 0;
            return newState;
        }
        
        //           If the after-restart bit is clear, stop.
        
        if (state.bitmap.afterRestart == 0) {
            return newState;
        }
        
        //           Run the inner finite state machine.
        
        BOOL terminalFlag = [self innerStateMachine: &newState
                                          character: chr];
        
        //           If it results in a keyword terminal (that is, a terminal
        //           which has inner state 0x100 or above):
        //              Set colour-backtrack (and record the backtrack colour
        //              as "function" colour).
        //              Clear after-restart.
        
        if (terminalFlag && newState.bitmap.inner >= 0x100) {
            newState.bitmap.colourBacktrack = 1;
            newState.bitmap.backtrackColour = IFSyntaxFunction;
            newState.bitmap.afterRestart = 0;
        }
        
        //           Stop.
		
        return newState;
    } else {
        //        If not:
        //           Is the character "["?
        //              If so:
        //                 Set the statement bit.
        //                 If the after-marker bit is clear, set after-restart.
        //                 Stop.
        
        if (chr == '[') {
            newState.bitmap.statement = 1;
            if (newState.bitmap.afterMarker == 0)
                newState.bitmap.afterRestart = 1;
            return newState;
        }
        
        //           Run the inner finite state machine.
        
        BOOL terminalFlag = [self innerStateMachine: &newState
                                          character: chr];
        
        //           If it results in a terminal:
        if (terminalFlag) {
            //              Is the inner state 2 [after "->"] or 3 [after "*"]?
            //                 If so:
            //                    Set after-marker.
            //                    Set colour-backtrack (and record the backtrack
            //                    colour as "directive" colour).
            //                    Zero the inner state.
            
            if (newState.bitmap.inner == 2) {
                newState.bitmap.afterMarker = 1;
                newState.bitmap.colourBacktrack = 1;
                newState.bitmap.backtrackColour = IFSyntaxDirective;
                newState.bitmap.inner = 0;
            }
            
            //              [If not, the terminal must be from a keyword.]
            //              Is the inner state 0x404 [after "with"]?
            //                 If so:
            //                    Set colour-backtrack (and record the backtrack
            //                    colour as "directive" colour).
            //                    Set after-marker.
            //                    Set highlight.
            //                    Clear highlight-all.
            
            else if (newState.bitmap.inner == 0x8404) {
                newState.bitmap.colourBacktrack = 1;
                newState.bitmap.backtrackColour = IFSyntaxDirective;
                newState.bitmap.afterMarker = 1;
                newState.bitmap.highlight = 1;
                newState.bitmap.highlightAll = 0;
            }
            
            //              Is the inner state 0x313 ["has"] or 0x525 ["class"]?
            //                 If so:
            //                    Set colour-backtrack (and record the backtrack
            //                    colour as "directive" colour).
            //                    Set after-marker.
            //                    Clear highlight.
            //                    Set highlight-all.
            
            else if (newState.bitmap.inner == 0x8313 || newState.bitmap.inner == 0x8525) {
                newState.bitmap.colourBacktrack = 1;
                newState.bitmap.backtrackColour = IFSyntaxDirective;
                newState.bitmap.afterMarker = 1;
                newState.bitmap.highlight = 0;
                newState.bitmap.highlightAll = 1;
            }
            
            //              If the inner state isn't one of these: [so that recent
            //              text has formed some alphanumeric token which might or
            //              might not be a reserved word of some kind]
            //                 If waiting-for-directive is set:
            //                       Set colour-backtrack (and record the backtrack
            //                       colour as "directive" colour)
            //                       Clear waiting-for-directive.
            //                 If not, but highlight-all is set:
            //                       Set colour-backtrack (and record the backtrack
            //                       colour as "property" colour)
            //                 If not, but highlight is set:
            //                       Clear highlight.
            //                       Set colour-backtrack (and record the backtrack
            //                       colour as "property" colour).
			
            else {
                if (newState.bitmap.waitingForDirective == 0) {
                    newState.bitmap.colourBacktrack = 1;
                    newState.bitmap.backtrackColour = IFSyntaxDirective;
                    newState.bitmap.waitingForDirective = 1;	// inverted
                } else if (newState.bitmap.highlightAll) {
                    newState.bitmap.colourBacktrack = 1;
                    newState.bitmap.backtrackColour = IFSyntaxProperty;
                } else if (newState.bitmap.highlight) {
                    newState.bitmap.highlight = 0;
                    newState.bitmap.colourBacktrack = 1;
                    newState.bitmap.backtrackColour = IFSyntaxProperty;
                }
            }
        }
		
		//              Is the character ";"?
		//                 If so:
		//                    Set wait-direct.
		//                    Clear after-marker.
		//                    Clear after-restart.
		//                    Clear highlight.
		//                    Clear highlight-all.
		
		if (chr == ';') {
			newState.bitmap.waitingForDirective = 0; // Inverted
			newState.bitmap.afterMarker = 0;
			newState.bitmap.afterRestart = 0;
			newState.bitmap.highlight = 0;
			newState.bitmap.highlightAll = 0;
		}
		
		//              Is the character ","?
		//                 If so:
		//                    Set after-marker.
		//                    Set highlight.
		
		if (chr == ',') {
			newState.bitmap.afterMarker = 1;
			newState.bitmap.highlight = 1;
		}
		
        //           Stop.
        
        return newState;
    }
}

#pragma mark - Initialisation

static int compare(const void* a, const void* b) {
    return strcmp(*((const char*const*)a),*((const char*const*)b));
}

+ (void) initialize {
    codeKwSet = [NSSet setWithObjects:
        @"box", @"break", @"child", @"children", @"continue", @"default",
        @"do", @"elder", @"eldest", @"else", @"false", @"font", @"for", @"give", @"glk",
        @"has", @"hasnt", @"if", @"in", @"indirect", @"inversion", @"jump",
        @"metaclass", @"move", @"new_line", @"nothing", @"notin", @"objectloop",
        @"ofclass", @"or", @"parent", @"print", @"print_ret", @"provides", @"quit",
        @"random", @"read", @"remove", @"restore", @"return", @"rfalse", @"rtrue",
        @"save", @"sibling", @"spaces", @"string", @"style", @"switch", @"to",
        @"true", @"until", @"while", @"younger", @"youngest", nil];
    
	/*
    otherKwSet = [[NSSet setWithObjects: 
        @"alias", @"additive", @"buffer", @"class", @"creature", @"data", @"error", @"fatalerror", 
		@"first", @"held", @"initial", @"initstr", @"last", @"long", @"meta", @"multi",
		@"multiexcept", @"multiheld", @"multiinside", @"noun", @"number", @"only", @"private", 
		@"replace", @"reverse", @"score", @"scope", @"special", @"string", @"table", @"terminating", 
		@"time", @"topic", @"warning", nil]
        retain];
	*/
    otherKwSet = [NSSet setWithObjects: 
        @"first", @"last", @"meta", @"only", @"private", @"replace", @"reverse",
        @"string", @"table", nil];
    
    for( NSString* key in codeKwSet ) {
        const char* str = key.lowercaseString.UTF8String;
        
        numCodeKeywords++;
        
        codeKeywords = realloc(codeKeywords, sizeof(char*) * (numCodeKeywords+1));
        codeKeywords[numCodeKeywords-1] = malloc(strlen(str)+1);
        strcpy(codeKeywords[numCodeKeywords-1], str);
    }

    for( NSString* key in otherKwSet ) {
        const char* str = key.lowercaseString.UTF8String;
        
        numOtherKeywords++;
        
        otherKeywords = realloc(otherKeywords, sizeof(char*) * (numOtherKeywords+1));
        otherKeywords[numOtherKeywords-1] = malloc(strlen(str)+1);
        strcpy(otherKeywords[numOtherKeywords-1], str);
    }

    qsort(codeKeywords, numCodeKeywords, sizeof(char*), compare);
    qsort(otherKeywords, numOtherKeywords, sizeof(char*), compare);
}

#pragma mark - Notifying of the highlighter currently in use

- (void) setSyntaxData: (IFSyntaxData*) aData {
	activeData = aData;
}

#pragma mark - The highlighter itself

- (IFSyntaxState) stateForCharacter: (unichar) chr
						 afterState: (IFSyntaxState) lastState {
	IFInform6State state;
	
	state.state = lastState;
	state.bitmap.colourBacktrack = 0; // Only lives once!
	
	return [self nextState: state
			 nextCharacter: chr].state;
}

- (IFSyntaxStyle) styleForCharacter: (unichar) chr
						  nextState: (IFSyntaxState) nextState
						  lastState: (IFSyntaxState) lastState {
	IFInform6State state;
	
	state.state = lastState;
    
	// Colour backtracking
	IFInform6State newState;
	newState.state = nextState;
	
	if (newState.bitmap.colourBacktrack) {
		int backLen = newState.bitmap.inner;
		
		backLen &= ~0x8000;
		backLen >>= 8;
		backLen++;
		
		[activeData backtrackWithStyle: newState.bitmap.backtrackColour
                                length: backLen];
	}

	// Colour for this character
    if (state.bitmap.singleQuote || state.bitmap.doubleQuote) return IFSyntaxString;
    if (state.bitmap.comment) return IFSyntaxComment;
    if (state.bitmap.statement) {
        if (chr == '[' || chr == ']') return IFSyntaxFunction;
        if (chr == '\'' || chr == '"') return IFSyntaxString;
        return IFSyntaxCodeAlpha;
    }
    
    if (chr == ',' || chr == ';' || chr == '*' || chr == '>') return IFSyntaxDirective;
    if (chr == '[' || chr == ']') return IFSyntaxFunction;
    if (chr == '\'' || chr == '"') return IFSyntaxString;
	
    return IFSyntaxNone;
}

- (void) rehintLine: (NSString*) line
			 styles: (IFSyntaxStyles*) styles
	   initialState: (IFSyntaxState) state {
    int x;
    int chr;
	
	const char* str = line.UTF8String;
	int strLen = (int) line.length;
    
    // Firstly, any characters with colour Q (quoted-text) which have special
    // meanings are given "escape-character colour" instead.  This applies
    // to "~", "^", "\" and "@" followed by (possibly) another "@" and a
    // number of digits.
    
    for (x=0; x<strLen; x++) {
        if ([styles read:x] == IFSyntaxString) {
            chr = str[x];
            
            switch (chr) {
                case '~': case '^': case '\\':
                    [styles write:x value:IFSyntaxEscapeCharacter];
                    break;
                    
                case '@':
                    [styles write:x value:IFSyntaxEscapeCharacter];
                    
                    if ((x+1) < strLen) {
                        chr = str[x+1];
                        
                        if (chr == '@') {
                            x++;
                            [styles write:x value:IFSyntaxEscapeCharacter];
                        }
                    }
						
						do {
							x++;
							if (x >= strLen) break;
							
							chr = str[x];
							
                            if (isdigit(chr)) [styles write:x value:IFSyntaxEscapeCharacter];
						} while (isdigit(chr));
						break;
            }
        }
    }
	
    // Next we look for identifiers.  An identifier for these purposes includes
    // a number, for it is just a sequence of:
    
    //      "_" or "$" or "#" or "0" to "9" or "a" to "z" or "A" to "Z".
	
    for (x=0; x<strLen; x++) {
        int identifierLen = 0;
        int identifierStart = x;
        unsigned char colour = [styles read:identifierStart];
        
        chr = str[x];
        
        if (colour != IFSyntaxCodeAlpha &&
            colour != IFSyntaxNone) {
            // No further highlighting will be required
            continue;
        }
        
        while (IsIdentifier(chr)) {
            identifierLen++;
            
            x++;
            if (x >= strLen) break;
            
            chr = str[x];
        }
        
        if (identifierLen == 0) continue;
		
        // The initial colouring of an identifier tells us its context.  We're
        // only interested in those in foreground colour (these must be used
        // in the body of a directive) or code colour (used in statements).
        
        unsigned char newColour = 0xff;
		
        if (colour == IFSyntaxCodeAlpha) {
            // If an identifier is in code colour, then:
			
            if (identifierStart > 0 && str[identifierStart-1] == '@') {
                //     If it follows an "@", recolour the "@" and the identifier in
                //        assembly-language colour.
                identifierStart--;
                identifierLen++;
                newColour = IFSyntaxAssembly;
            } else {
                //     Otherwise, unless it is one of the following:
				
                //       "box"  "break"  "child"  "children"  "continue"  "default"
                //       "do"  "elder"  "eldest"  "else"  "false"  "font"  "for"  "give"
                //       "has"  "hasnt"  "if"  "in"  "indirect"  "inversion"  "jump"
                //       "metaclass"  "move"  "new_line"  "nothing"  "notin"  "objectloop"
                //       "ofclass"  "or"  "parent"  "print"  "print_ret"  "provides"  "quit"
                //       "random"  "read"  "remove"  "restore"  "return"  "rfalse"  "rtrue"
                //       "save"  "sibling"  "spaces"  "string"  "style"  "switch"  "to"
                //       "true"  "until"  "while"  "younger"  "youngest"
				
                //     we recolour the identifier to "codealpha colour".
                char* identifier = malloc(identifierLen+1);
                identifier = strncpy(identifier, str + identifierStart, identifierLen);
                identifier[identifierLen] = 0;
                
                if (FindKeyword(codeKeywords, numCodeKeywords, identifier)) newColour = IFSyntaxCode;
                
                free(identifier);
            }
        } else if (colour == IFSyntaxNone) {
            // On the other hand, if an identifier is in foreground colour, then we
            // check it to see if it's one of the following interesting keywords:
            
            //       "first"  "last"  "meta"  "only"  "private"  "replace"  "reverse"
            //       "string"  "table"
            
            // If it is, we recolour it in directive colour.
            
            char* identifier = malloc(identifierLen+1);
            identifier = strncpy(identifier, str + identifierStart, identifierLen);
            identifier[identifierLen] = 0;
            
            if (FindKeyword(otherKeywords, numOtherKeywords, identifier)) {
                newColour = IFSyntaxDirective;
            }
            
            free(identifier);
        }
        
        if (newColour != 0xff) {
            for (int y=identifierStart; y< (identifierStart + identifierLen); y++) {
                [styles write:y value:newColour];
            }
        }
    }	
}

#pragma mark - Styles

- (NSDictionary*) attributesForStyle: (IFSyntaxStyle) style {
	return [IFProjectPane attributeForStyle: style];
}

- (CGFloat) tabStopWidth {
	return 28.0;
}

@end
