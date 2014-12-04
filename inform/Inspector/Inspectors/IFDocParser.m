//
//  IFDocParser.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 28/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFDocParser.h"

// = Information about a find within an example
@implementation IFExampleInfo
-(id) initWithName:(NSString*) aName anchorTag:(NSString*) aAnchorTag range:(NSRange)aRange {
	self = [super init];
	
	if (self) {
        name      = [aName retain];
        anchorTag = [aAnchorTag retain];
        range     = aRange;
    }
    return self;
}

-(void) dealloc {
    [name release];
    [anchorTag release];
    [super dealloc];
}

-(NSString *) name {
    return name;
}

-(NSString *) anchorTag {
    return anchorTag;
}

-(NSRange) range {
    return range;
}
@end

@implementation IFCodeInfo
-(id) initWithAnchorTag:(NSString*) aAnchorTag range:(NSRange)aRange {
	self = [super init];
	
	if (self) {
        anchorTag = [aAnchorTag retain];
        range     = aRange;
    }
    return self;
}

-(void) dealloc {
    [anchorTag release];
    [super dealloc];
}

-(NSString *) anchorTag {
    return anchorTag;
}

-(NSRange) range {
    return range;
}
@end

@implementation IFDocParser

NSString* IFDocHtmlTitleAttribute = @"IFDocHtmlTitle";
NSString* IFDocTitleAttribute = @"IFDocTitle";
NSString* IFDocSectionAttribute = @"IFDocSection";
NSString* IFDocSortAttribute = @"IFDocSort";

// = Static dictionaries =

static NSSet* ignoreTags = nil;
static NSDictionary* entities = nil;

// = Initialisation =

+ (void) initialize {
	if (ignoreTags == nil) {
		ignoreTags = [[NSSet alloc] initWithObjects:
			@"head", @"script", 
			nil];
		entities = [[NSDictionary alloc] initWithObjectsAndKeys:
			@"<", @"lt",
			@">", @"gt",
			@"\"", @"quot",
			@" ", @"nbsp",
			nil];
	}
}

typedef enum {
	PlainText,
	HtmlTagOrComment,
	HtmlTag,
	HtmlCloseTag,
	HtmlComment,
	HtmlCommentEnd1,
	HtmlCommentEnd2,
	HtmlEntity
} ParseState;

- (id) initWithHtml: (NSString*) html {
	self = [super init];
	
	if (self) {
		// Prepare the results string
		NSMutableDictionary*    attr     = [[NSMutableDictionary alloc] init];
		NSMutableDictionary*    exInfo   = [[NSMutableDictionary alloc] init];
        NSMutableArray*         cdInfo   = [[NSMutableArray alloc] init];
        NSMutableArray*         dfInfo   = [[NSMutableArray alloc] init];
		
		// Parse the HTML
		int len = [html length];
		unichar* chrs = malloc(sizeof(unichar)*(len+1));
		unichar* result = malloc(sizeof(unichar)*(len+1));
		[html getCharacters: chrs];
		int resultLength = 0;
		
		int         x;
		ParseState  state = PlainText;
		BOOL        whitespace = YES;
		BOOL        inTitle = NO;
        NSString*   exampleName = @"";
        NSString*   exampleAnchorTag = @"";
        int         exampleStartLocation = 0;
        int         codeStartLocation = 0;
        NSString*   codeAnchorTag = @"";
        int         definitionStartLocation = 0;
        NSString*   definitionAnchorTag = @"";
        bool        ignoreSection = false;
        
		unichar* title = malloc(sizeof(unichar)*(len+1));
		int titleLength = 0;
		
		int tagStart = 0;
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
							NSString* entityValue = [entities objectForKey: entity];

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
							state = HtmlComment;
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
							int spaceLoc = [tag rangeOfString: @" "].location;
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
							// End of this comment
							state = PlainText;

							NSString* comment = [NSString stringWithCharacters: chrs + tagStart
																		length: x - tagStart];
							
							// Strip down this comment
							comment = [comment substringFromIndex: 5];					// Removes <!-- 
							comment = [comment substringToIndex: [comment length]-3];	// Removes --
							
							// Look for interesting comments
							if ([comment hasPrefix: @"START EXAMPLE \""]) {
								int prefixLen = [@"START EXAMPLE \"" length];
                                // Remember the name, anchor id and location of the Example
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];

                                if( [array count] == 2 ) {
                                    exampleName = [[array objectAtIndex:0] retain];
                                    exampleAnchorTag = [[array objectAtIndex:1] retain];
                                    exampleStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END EXAMPLE"]) {
                                int exampleEndLocation = resultLength;
                                // Record the range for this example
                                if( [exInfo objectForKey: exampleName] == nil ) {
                                    NSRange range = NSMakeRange(exampleStartLocation, exampleEndLocation - exampleStartLocation);
                                    IFExampleInfo* info = [[IFExampleInfo alloc] initWithName: exampleName
                                                                                    anchorTag: exampleAnchorTag
                                                                                        range: range];
                                    [exInfo setObject:info forKey: exampleName];
                                    [info release];
                                }
							} else if ([comment hasPrefix: @"START CODE"]) {
								int prefixLen = [@"START CODE \"" length];
                                // Remember the anchor id
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];
                                
                                if( [array count] == 1 ) {
                                    codeAnchorTag = [[array objectAtIndex:0] retain];
                                    codeStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END CODE"]) {
                                int codeEndLocation = resultLength;
                                // Record the range for this code
                                NSRange range = NSMakeRange(codeStartLocation, codeEndLocation - codeStartLocation);
                                IFCodeInfo* info = [[IFCodeInfo alloc] initWithAnchorTag: codeAnchorTag
                                                                                   range: range];
                                [cdInfo addObject: info];
							} else if ([comment hasPrefix: @"START PHRASE"]) {
								int prefixLen = [@"START PHRASE \"" length];
                                // Remember the anchor id
								NSString* postfix = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
                                NSArray*  array   = [postfix componentsSeparatedByString:@"\" \""];
                                
                                if( [array count] == 1 ) {
                                    definitionAnchorTag = [[array objectAtIndex:0] retain];
                                    definitionStartLocation = resultLength;
                                }
							} else if ([comment hasPrefix: @"END PHRASE"]) {
                                int definitionEndLocation = resultLength;
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
								int prefixLen = [@"SEARCH TITLE \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
								
								[attr setObject: comment
										 forKey: IFDocTitleAttribute];
							} else if ([comment hasPrefix: @"SEARCH SECTION \""]) {
								int prefixLen = [@"SEARCH SECTION \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+1))];
								
								[attr setObject: comment
										 forKey: IFDocSectionAttribute];
							} else if ([comment hasPrefix: @"SEARCH SORT \""]) {
								int prefixLen = [@"SEARCH SORT \"" length];
								comment = [comment substringWithRange: NSMakeRange(prefixLen, [comment length]-(prefixLen+2))];
								
								[attr setObject: comment
										 forKey: IFDocSortAttribute];
							}
							break;
							
						case '-':
							// Comment might end later on
							break;
							
						default:
							// The comment continues
							state = HtmlComment;
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
		[attr setObject: [NSString stringWithCharacters: title
												 length: titleLength]
				 forKey: IFDocHtmlTitleAttribute];

		plainText       = [[NSString stringWithCharacters: result
                                                   length: resultLength] retain];
        exampleInfo     = [[NSDictionary dictionaryWithDictionary:exInfo] retain];
        codeInfo        = [[NSArray arrayWithArray: cdInfo] retain];
        definitionInfo  = [[NSArray arrayWithArray: dfInfo] retain];

        [exInfo release];
        [cdInfo release];
        [dfInfo release];

        exInfo      = nil;
        cdInfo      = nil;
		attributes  = attr;

		free(chrs);
		free(result);
		free(title);
	}

	return self;
}

- (void) dealloc {
	[plainText release];
	[attributes release];
	[exampleInfo release];
	
	[super dealloc];
}

// = The results =

- (NSString*) plainText {
	return plainText;
}

- (NSDictionary*) attributes {
	return attributes;
}

- (NSDictionary*) exampleInfo {
	return exampleInfo;
}

- (NSArray*) codeInfo {
	return codeInfo;
}

- (NSArray*) definitionInfo {
    return definitionInfo;
}

@end
