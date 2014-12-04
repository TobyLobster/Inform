//
//  IFFindResult.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 17/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	// The main types of find that can be performed
    IFFindInvalidType = 0,
	IFFindContains,
	IFFindBeginsWith,
	IFFindCompleteWord,
	IFFindRegexp,
	
	// Flags that can be applied to the find types
	IFFindCaseInsensitive = 0x100,
} IFFindType;

typedef enum {
    IFFindNowhere                   = 0,
    IFFindCurrentPage               = 1,
    IFFindSource                    = 2,
    IFFindExtensions                = 4,
    IFFindDocumentationBasic        = 8,
    IFFindDocumentationSource       = 16,
    IFFindDocumentationDefinitions  = 32,
} IFFindLocation;


///
/// Result for the 'Find All' pane
///
@interface IFFindResult : NSObject<NSCopying> {
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

// Initialisation
-(id)   initWithFilepath: (NSString*)       filepath
             rangeInFile: (NSRange)         fileRange
     documentDisplayName: (NSString*)       documentDisplayName
        documentSortName: (NSString*)       documentSortName
            locationType: (IFFindLocation)  locationType
                 context: (NSString*)       context
            contextRange: (NSRange)         contextRange
             exampleName: (NSString*)       aExampleName
        exampleAnchorTag: (NSString*)       aExampleAnchorTag
           codeAnchorTag: (NSString*)       aCodeAnchorTag
     definitionAnchorTag: (NSString*)       aDefinitionAnchorTag
        regexFoundGroups: (NSArray*)        aRegexFoundGroups;

// Data
- (NSString*)       filepath;                       // The filepath of the file in which the result was found
- (NSRange)         fileRange;                      // The range within the file of the match
- (NSString*)       documentDisplayName;            // The document name diaplyed in the results
- (NSString*)       documentSortName;               // Name used for sorting the results into order
- (IFFindLocation)  locationType;					// The location type of the match
- (NSString*)       context;						// The context the match was found in
- (NSRange)         contextRange;					// The range in the context of the match
- (NSString*)       exampleName;                    // The name of the example where it was found
- (NSString*)       exampleAnchorTag;               // The HTML anchor tag of the example where the result was found
- (NSString*)       codeAnchorTag;                  // The HTML anchor tag of the code where the result was found
- (NSString*)       definitionAnchorTag;            // The HTML anchor tag of the definition where the result was found
- (NSString*)       phrase;                         // The search phrase
- (NSArray*)        regexFoundGroups;               // Array of strings for the found regex groups
- (void)            setError:(BOOL) hasError;

- (bool)            isWritingWithInformResult;      // Is the result found in the WritingWithInform documentation?
- (bool)            isRecipeBookResult;             // Is the result found in the Recipe Book documentation?

- (NSAttributedString*) attributedContext;
- (NSString*)       stringByReplacingGroups:(NSString*) replace;

+ (NSString*)       stringByReplacingGroups:(NSString*) replace regexFoundGroups:(NSArray*) aRegexFoundGroups;

@end
