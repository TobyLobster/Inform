//
//  IFFindResult.m
//  Inform
//
//  Created by Andrew Hunter on 17/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFFindResult.h"
#import "IFUtility.h"

@implementation IFFindResult {
    NSString*       filepath;
    NSRange         fileRange;
    NSString*       documentDisplayName;
    NSString*       documentSortName;
    IFFindLocation  locationType;
    NSString*       context;
    NSRange         contextRange;
    NSString*       exampleName;
    NSString*       exampleAnchorTag;
    NSString*       codeAnchorTag;
    NSString*       definitionAnchorTag;
    NSArray*        regexFoundGroups;

    BOOL            hasError;
}

#pragma mark - Initialisation

- (instancetype)   initWithFilepath: (NSString*)       aFilepath
                        rangeInFile: (NSRange)         aFileRange
                documentDisplayName: (NSString*)       aDocumentDisplayName
                   documentSortName: (NSString*)       aDocumentSortName
                       locationType: (IFFindLocation)  aLocationType
                            context: (NSString*)       aContext
                       contextRange: (NSRange)         aContextRange
                        exampleName: (NSString*)       aExampleName
                   exampleAnchorTag: (NSString*)       aExampleAnchorTag
                      codeAnchorTag: (NSString*)       aCodeAnchorTag
                definitionAnchorTag: (NSString*)       aDefinitionAnchorTag
                   regexFoundGroups: (NSArray*)        aRegexFoundGroups {

	self = [super init];
	
	if (self) {
        filepath            = aFilepath;
        fileRange           = aFileRange;
        documentDisplayName = aDocumentDisplayName;
        documentSortName    = aDocumentSortName;
        locationType        = aLocationType;
        context             = aContext;
        contextRange        = aContextRange;
        exampleName         = aExampleName;
        exampleAnchorTag    = aExampleAnchorTag;
        codeAnchorTag       = aCodeAnchorTag;
        definitionAnchorTag = aDefinitionAnchorTag;
        regexFoundGroups    = [aRegexFoundGroups copy];
	}

	return self;
}


#pragma mark - Data

@synthesize filepath;
@synthesize fileRange;

- (NSString*) phrase {
    return [self.context substringWithRange:self.contextRange];
}

@synthesize documentDisplayName;
@synthesize documentSortName;
@synthesize locationType;
@synthesize context;
@synthesize contextRange;
@synthesize exampleName;
@synthesize exampleAnchorTag;
@synthesize codeAnchorTag;
@synthesize definitionAnchorTag;
@synthesize regexFoundGroups;

- (NSString*) foundMatchString {
    return [context substringWithRange:contextRange];
}

- (bool) isWritingWithInformResult {
    // sort name starts with 000 for Writing With Inform
    // sort name starts with 001 for The Inform Recipe Book
    return [documentSortName hasPrefix:@"000"];
}

- (bool) isRecipeBookResult {
    return [documentSortName hasPrefix:@"001"];
}

- (void) setError: (BOOL) newHasError {
	hasError = newHasError;
}

+ (NSString*) stringByReplacingGroups:(NSString*) replace regexFoundGroups:(NSArray*) aRegexFoundGroups {
    //
    // In a regex replacement string, we want:
    //
    //      \0 through \9 to be replaced with the corresponding found group.
    //      \\ to \.
    //      \t \r \v \f \n to newline/tab characters 8, 10, 11, 12, 13.
    //      \x09 (etc) to utf8 code
    //
    NSMutableString* mutReplace = [[NSMutableString alloc] init];
    [mutReplace setString:replace];
    
    bool foundSlash = false;
    for(int i = 0; i < mutReplace.length; i++ ) {
        unichar c = [mutReplace characterAtIndex:i];

        if( c == '\\' ) {
            if( foundSlash ) {
                // We have found '\\'. We Remove the second slash.
                [mutReplace deleteCharactersInRange: NSMakeRange(i, 1)];
                i--;
                foundSlash = false;
            } else {
                // We have found our first slash
                foundSlash = true;
            }
        } else if (foundSlash) {
            if ((c >= '0') && (c <= '9')) {
                // We have found one of \0 to \9
                int group = (int) c - '0';
                
                if( aRegexFoundGroups.count > group ) {
                    // Remove the \0
                    [mutReplace deleteCharactersInRange: NSMakeRange(i-1, 1)];
                    [mutReplace deleteCharactersInRange: NSMakeRange(i-1, 1)];

                    NSString* groupString;
                    groupString = aRegexFoundGroups[group];

                    // Insert the matched string
                    [mutReplace insertString:groupString atIndex: i-1];
                    i = (i-1) + (int) (groupString.length-1);
                }
            }
            else if ((c == 't') || (c == 'r') || (c == 'v') || (c == 'f') || (c == 'n')) {
                if( c== 't' ) c = 9;
                else if( c== 'r' ) c = 10;
                else if( c== 'v' ) c = 11;
                else if( c== 'f' ) c = 12;
                else if( c== 'n' ) c = 13;
                NSString*unicharString = [NSString stringWithFormat:@"%C", c];
                [mutReplace replaceCharactersInRange:NSMakeRange(i-1, 2) withString:unicharString];
            } else if (c == 'x') {
                if( i < (mutReplace.length - 2)) {
                    unsigned int hexInt;
                    NSScanner* scanner = [NSScanner scannerWithString:[mutReplace substringWithRange:NSMakeRange(i+1, 2)]];
                    
                    [scanner scanHexInt:&hexInt];
                    NSString*unicharString = [NSString stringWithFormat:@"%C", (unichar) hexInt];
                    [mutReplace replaceCharactersInRange:NSMakeRange(i-1, 4) withString:unicharString];
                }
            }
            foundSlash = false;
        }
    }
    return mutReplace;
}

- (NSString*) stringByReplacingGroups:(NSString*) replace {
    return [IFFindResult stringByReplacingGroups:replace regexFoundGroups:regexFoundGroups];
}

- (NSAttributedString*) attributedContext {
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

    NSDictionary* italicsAttributes;
    NSDictionary* normalAttributes;
    NSDictionary* boldAttributes;
    if( hasError )
    {
        italicsAttributes = @{ NSFontAttributeName: [NSFont fontWithName:@"Helvetica" size: 11], // system font doesn't do italics, so we use Helvetica instead.
                               NSForegroundColorAttributeName: [NSColor systemRedColor],
                               NSParagraphStyleAttributeName: style };
        normalAttributes = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11],
                              NSForegroundColorAttributeName: [NSColor systemRedColor],
                              NSParagraphStyleAttributeName: style };
        boldAttributes = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12],
                            NSForegroundColorAttributeName: [NSColor systemRedColor],
                            NSParagraphStyleAttributeName: style };
    }
    else
    {
        italicsAttributes = @{ NSFontAttributeName: [NSFont fontWithName:@"Helvetica" size: 11], // system font doesn't do italics, so we use Helvetica instead.
                               NSForegroundColorAttributeName: [NSColor textColor],
                               NSParagraphStyleAttributeName: style};
        normalAttributes = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11],
                              NSForegroundColorAttributeName: [NSColor textColor],
                              NSParagraphStyleAttributeName: style};
        boldAttributes = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12],
                            NSForegroundColorAttributeName: [NSColor textColor],
                            NSParagraphStyleAttributeName: style};
    }

	NSMutableAttributedString* result = [[NSMutableAttributedString alloc] initWithString: self.context
																				attributes: normalAttributes];
    [result beginEditing];
	[result addAttributes: boldAttributes
					range: self.contextRange];
    [result applyFontTraits:NSBoldFontMask range:self.contextRange];

    // Prefix with example, if there is one
    if((exampleName != nil) && (exampleName.length > 0 )) {
        NSString* prefix = [IFUtility localizedString: @"SearchResultInExamplePrefix"
                                              default: @"(Example %@)  "];
        prefix = [NSString stringWithFormat: prefix, exampleName];
        NSAttributedString* examplePrefix = [[NSAttributedString alloc] initWithString:prefix attributes:italicsAttributes];
        [result insertAttributedString:examplePrefix atIndex:0];

        [result applyFontTraits: NSItalicFontMask
                          range: NSMakeRange(0, examplePrefix.length)];
    }
    [result endEditing];

	return result;
}

#pragma mark - Copying

- (id) copyWithZone: (NSZone*) zone {
	return self;
}

@end
