//
//  IFDocParser.m
//  Inform
//
//  Created by Andrew Hunter on 28/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFDocParser.h"

// = Information about a find within an example
@implementation IFExampleInfo {
    NSString*   name;
    NSString*   anchorTag;
    NSRange     range;
}

-(instancetype) init { self = [super init]; return self; }

-(instancetype) initWithName:(NSString*) aName anchorTag:(NSString*) aAnchorTag range:(NSRange)aRange {
	self = [super init];
	
	if (self) {
        name      = aName;
        anchorTag = aAnchorTag;
        range     = aRange;
    }
    return self;
}

@synthesize name;
@synthesize anchorTag;
@synthesize range;

@end

@implementation IFCodeInfo {
    NSString*   anchorTag;
    NSRange     range;
}

-(instancetype) init { self = [super init]; return self; }

-(instancetype) initWithAnchorTag:(NSString*) aAnchorTag range:(NSRange)aRange {
	self = [super init];
	
	if (self) {
        anchorTag = aAnchorTag;
        range     = aRange;
    }
    return self;
}

@synthesize anchorTag;
@synthesize range;
@end

@implementation IFDocParser {
    // The parse results
    /// The plain text version of the HTML document
    NSString*       plainText;
    /// The attributes associated with the HTML document
    NSDictionary<IFDocAttributeKey,id>*   attributes;
    /// Dictionary of examples in the document. Keys are string version of example name, values are IFExampleInfo.
    NSDictionary<NSString*,IFExampleInfo*>*   exampleInfo;
    /// Array of \c IFCodeInfo specifying ranges in the document where code occurs.
    NSArray<IFCodeInfo*>*        codeInfo;
    /// Array of \c IFCodeInfo specifying ranges in the document where definitions occur.
    NSArray<IFCodeInfo*>*        definitionInfo;
}

NSString* const IFDocAttributeHtmlTitle = @"IFDocHtmlTitle";
NSString* const IFDocAttributeTitle = @"IFDocTitle";
NSString* const IFDocAttributeSection = @"IFDocSection";
NSString* const IFDocAttributeSort = @"IFDocSort";

#pragma mark - Static dictionaries

static NSSet<NSString*>* ignoreTags = nil;
static NSDictionary<NSString*,NSString*>* entities = nil;

#pragma mark - Initialisation

+ (void) initialize {
	if (ignoreTags == nil) {
		ignoreTags = [[NSSet alloc] initWithObjects:
			@"head", @"script", 
			nil];
		entities = @{@"lt": @"<",
			@"gt": @">",
			@"quot": @"\"",
			@"nbsp": @" "};
	}
}

typedef NS_ENUM(unsigned int, ParseState) {
	PlainText,
	HtmlTagOrComment,
	HtmlTag,
	HtmlCloseTag,
    HtmlCommentStart1,
    HtmlCommentStart2,
    HtmlComment,
	HtmlCommentEnd1,
	HtmlCommentEnd2,
	HtmlEntity
};

-(instancetype) init { self = [super init]; return self; }

- (instancetype) initWithHtml: (NSString*) html {
	self = [super init];
	
	if (self) {
		// Prepare the results string
		NSMutableDictionary*    attr     = [[NSMutableDictionary alloc] init];
		NSMutableDictionary*    exInfo   = [[NSMutableDictionary alloc] init];
        NSMutableArray*         cdInfo   = [[NSMutableArray alloc] init];
        NSMutableArray*         dfInfo   = [[NSMutableArray alloc] init];
		
		// Parse the HTML
		NSInteger len = [html length];
		unichar* chrs = malloc(sizeof(unichar)*(len+1));
		unichar* result = malloc(sizeof(unichar)*(len+1));
		[html getCharacters: chrs];
        NSInteger resultLength = 0;
		
		NSInteger   x;
		ParseState  state = PlainText;
		BOOL        whitespace = YES;
		BOOL        inTitle = NO;
        NSString*   exampleName = @"";
        NSString*   exampleAnchorTag = @"";
        NSInteger   exampleStartLocation = 0;
        NSInteger   codeStartLocation = 0;
        NSString*   codeAnchorTag = @"";
        NSInteger   definitionStartLocation = 0;
        NSString*   definitionAnchorTag = @"";
        bool        ignoreSection = false;
        
		unichar* title = malloc(sizeof(unichar)*(len+1));
		NSInteger titleLength = 0;
		
		NSInteger tagStart = 0;
		int ignoreCount = 0;
		
		for (x=0; x<len; x++) {
			switch (state) {
				case PlainText:
					// This is a plain text section
					switch (chrs[x]) {
						case ' ':
						case '\t':
						case '\n':
						case '\r':
							// This is whitespace: append a maximum of one item of whitespace at a time
							if (inTitle && !whitespace) {
								whitespace = YES;
								title[titleLength++] = ' ';
							}
							if (ignoreCount) break;
                            if (ignoreSection) break;

							if (!whitespace) {
								whitespace = YES;
								result[resultLength++] = ' ';
							}
							break;
							
						case '<':
							// This is the beginning of a comment or a tag
							state = HtmlTagOrComment;
							tagStart = x;

							if (ignoreCount) break;
                            if (ignoreSection) break;

                            // Add a single character of whitespace to separate text.
							if (!whitespace) {
								whitespace = YES;
								result[resultLength++] = ' ';
							}
							break;
							
						case '&':
							// This is the beginning of an entity
							state = HtmlEntity;
							tagStart = x;
							break;
							
						default:
							// This is a non-whitespace character
							if (inTitle) {
								whitespace = NO;
								title[titleLength++] = chrs[x];
							}
							if (ignoreCount) break;
                            if (ignoreSection) break;

							whitespace = NO;
							result[resultLength++] = chrs[x];
							break;
					}
					break;
					
				case HtmlEntity:
					switch (chrs[x]) {
						case ' ':
						case '\t':
						case '\n':
						case '\r':
						case ';':
						{
							NSString* entity = [NSString stringWithCharacters: chrs + tagStart+1
																	   length: x - (tagStart+1)];
							entity = [entity lowercaseString];
							NSString* entityValue = entities[entity];

							// End of this entity
							state = PlainText;
							if (inTitle) {
								whitespace = NO;
								title[titleLength++] = [entityValue characterAtIndex: 0];
							}
							if (ignoreCount) break;
                            if (ignoreSection) break;
							
							whitespace = NO;
							if (entityValue != nil) {
								result[resultLength++] = [entityValue characterAtIndex: 0];
							}
							break;
						}
							
						default:
							// The entity continues
							break;
					}
					break;
					
				case HtmlTagOrComment:
					// This is either the beginning of a tag, or the beginning of a comment, or the beginning of a close tag
					switch (chrs[x]) {
						case '/':
							state = HtmlCloseTag;
							tagStart = x;
							break;
							
						case '!':
							state = HtmlCommentStart1;
							break;
							
						case '>':
							state = PlainText;
							break;
							
						default:
							state = HtmlTag;
							break;
					}
					break;
					
				case HtmlTag:
				case HtmlCloseTag:
					switch (chrs[x]) {
						case '>':
						{
							// End of this tag

							// Get the tag
							NSString* tag = [NSString stringWithCharacters: chrs + tagStart + 1
																	length: x - (tagStart + 1)];
							NSUInteger spaceLoc = [tag rangeOfString: @" "].location;
							if (spaceLoc != NSNotFound) tag = [tag substringToIndex: spaceLoc];
								
							tag = [tag lowercaseString];
							
							// If this is an ignore tag, then increase/decrease the ignore count
							if ([ignoreTags containsObject: tag]) {
								if (state == HtmlTag) {
									ignoreCount++;
								} else {
									ignoreCount--;
								}
							}
							
							if (ignoreCount <= 0 && ([tag isEqualToString: @"br"] ||
                                                     [tag isEqualToString: @"p"])) {
                                if( !ignoreSection ) {
                                    whitespace = YES;
                                    result[resultLength++] = '\n';
                                }
							}
							
							if ([tag isEqualToString: @"title"]) {
								if (state == HtmlTag) {
									inTitle = YES;
									whitespace = YES;
								} else {
									inTitle = NO;
									whitespace = YES;
								}
							}

							state = PlainText;
							break;
						}
							
						default:
							// The tag continues
							break;
					}
					break;
					
                case HtmlCommentStart1:
                    switch (chrs[x]) {
                        case '-':
                            state = HtmlCommentStart2;
                            break;

                        default:
                            state = HtmlTag;
                            break;
                    }
                    break;

                case HtmlCommentStart2:
                    switch (chrs[x]) {
                        case '-':
                            state = HtmlComment;
                            break;

                        default:
                            state = HtmlTag;
                            break;
                    }
                    break;

				case HtmlComment:
					switch (chrs[x]) {
						case '-':
							state = HtmlCommentEnd1;
							break;
							
						default:
							// The comment continues
							break;
					}
					break;
					
				case HtmlCommentEnd1:
					switch (chrs[x]) {
						case '-':
							// '--' has been matched if we get here
							state = HtmlCommentEnd2;
							break;
							
						default:
							// The comment continues
							state = HtmlComment;
							break;
					}
					break;
					
				case HtmlCommentEnd2:
					switch (chrs[x]) {
						case '>':
                        {
							// End of this comment
							state = PlainText;

							NSString* comment = [NSString stringWithCharacters: chrs + tagStart
																		length: x - tagStart];
							
							// Strip down this comment
							comment = [comment substringFromIndex: 4];					// Removes <!--
							comment = [comment substringToIndex: [comment length]-2];	// Removes --
							
							// Look for interesting comments
							if ([comment hasPrefix: @"START EXAMPLE \""]) {
								int prefixLen = (int) [@"START EXAMPLE \"" length];
                                // Remember the name, anchor id and location of the Example
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];

                                if( [array count] == 2 ) {
                                    exampleName = array[0];
                                    exampleAnchorTag = array[1];
                                    exampleStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END EXAMPLE"]) {
                                NSInteger exampleEndLocation = resultLength;
                                // Record the range for this example
                                if( exInfo[exampleName] == nil ) {
                                    NSRange range = NSMakeRange(exampleStartLocation, exampleEndLocation - exampleStartLocation);
                                    IFExampleInfo* info = [[IFExampleInfo alloc] initWithName: exampleName
                                                                                    anchorTag: exampleAnchorTag
                                                                                        range: range];
                                    exInfo[exampleName] = info;
                                }
							} else if ([comment hasPrefix: @"START CODE"]) {
								int prefixLen = (int) [@"START CODE \"" length];
                                // Remember the anchor id
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];
                                
                                if( [array count] == 1 ) {
                                    codeAnchorTag = array[0];
                                    codeStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END CODE"]) {
                                NSInteger codeEndLocation = resultLength;
                                // Record the range for this code
                                NSRange range = NSMakeRange(codeStartLocation, codeEndLocation - codeStartLocation);
                                IFCodeInfo* info = [[IFCodeInfo alloc] initWithAnchorTag: codeAnchorTag
                                                                                   range: range];
                                [cdInfo addObject: info];
							} else if ([comment hasPrefix: @"START PHRASE"]) {
								int prefixLen = (int) [@"START PHRASE \"" length];
                                // Remember the anchor id
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];
                                
                                if( [array count] == 1 ) {
                                    definitionAnchorTag = array[0];
                                    definitionStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END PHRASE"]) {
                                NSInteger definitionEndLocation = resultLength;
                                // Record the range for this code
                                NSRange range = NSMakeRange(definitionStartLocation, definitionEndLocation - definitionStartLocation);
                                IFCodeInfo* info = [[IFCodeInfo alloc] initWithAnchorTag: definitionAnchorTag
                                                                                   range: range];
                                [dfInfo addObject: info];
							} else if ([comment hasPrefix: @"START IGNORE"]) {
                                ignoreSection = true;
							} else if ([comment hasPrefix: @"END IGNORE"]) {
                                ignoreSection = false;
							} else if ([comment hasPrefix: @"SEARCH TITLE \""]) {
								int prefixLen = (int) [@"SEARCH TITLE \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
								
								attr[IFDocAttributeTitle] = comment;
							} else if ([comment hasPrefix: @"SEARCH SECTION \""]) {
								int prefixLen = (int) [@"SEARCH SECTION \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
								
								attr[IFDocAttributeSection] = comment;
							} else if ([comment hasPrefix: @"SEARCH SORT \""]) {
								int prefixLen = (int) [@"SEARCH SORT \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+2))];
								
								attr[IFDocAttributeSort] = comment;
							}
                        }
						break;
							
						case '-':
                        {
							// Comment might end later on
                        }
						break;
							
						default:
                        {
							// The comment continues
							state = HtmlComment;
                        }
						break;
					}
			}
		}
		
		// Sanity check
		if (resultLength > len) {
			NSLog(@"Crap: plain text is longer than HTML (stack corrupted; bombing out)");
			abort();
		}

		// Tidy up
		attr[IFDocAttributeHtmlTitle] = [[NSString alloc] initWithCharactersNoCopy: title
                                                                            length: titleLength
                                                                      freeWhenDone: YES];

		plainText       = [[NSString alloc] initWithCharactersNoCopy: result
                                                              length: resultLength
                                                        freeWhenDone: YES];
        exampleInfo     = [NSDictionary dictionaryWithDictionary:exInfo];
        codeInfo        = [NSArray arrayWithArray: cdInfo];
        definitionInfo  = [NSArray arrayWithArray: dfInfo];

        exInfo      = nil;
        cdInfo      = nil;
		attributes  = attr;

		free(chrs);
	}

	return self;
}

#pragma mark - The results

@synthesize plainText;
@synthesize attributes;
@synthesize exampleInfo;
@synthesize codeInfo;
@synthesize definitionInfo;

@end
