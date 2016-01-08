//
//  IFFindResult.h
//  Inform
//
//  Created by Andrew Hunter on 17/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(unsigned int, IFFindType) {
	// The main types of find that can be performed
    IFFindInvalidType = 0,
	IFFindContains,
	IFFindBeginsWith,
	IFFindCompleteWord,
	IFFindRegexp,
	
	// Flags that can be applied to the find types
	IFFindCaseInsensitive = 0x100,
};

typedef NS_OPTIONS(unsigned int, IFFindLocation) {
    IFFindNowhere                   = 0,
    IFFindCurrentPage               = 1,
    IFFindSource                    = 2,
    IFFindExtensions                = 4,
    IFFindDocumentationBasic        = 8,
    IFFindDocumentationSource       = 16,
    IFFindDocumentationDefinitions  = 32,
};


///
/// Result for the 'Find All' pane
///
@interface IFFindResult : NSObject<NSCopying>

// Data
@property (atomic, readonly, copy) NSString *   filepath;               // The filepath of the file in which the result was found
@property (atomic, readonly)       NSRange      fileRange;              // The range within the file of the match
@property (atomic, readonly, copy) NSString *   documentDisplayName;    // The document name diaplyed in the results
@property (atomic, readonly, copy) NSString *   documentSortName;       // Name used for sorting the results into order
@property (atomic, readonly)       IFFindLocation locationType;         // The location type of the match
@property (atomic, readonly, copy) NSString *   context;				// The context the match was found in
@property (atomic, readonly)       NSRange      contextRange;			// The range in the context of the match
@property (atomic, readonly, copy) NSString *   exampleName;            // The name of the example where it was found
@property (atomic, readonly, copy) NSString *   exampleAnchorTag;       // The HTML anchor tag of the example where the result was found
@property (atomic, readonly, copy) NSString *   codeAnchorTag;          // The HTML anchor tag of the code where the result was found
@property (atomic, readonly, copy) NSString *   definitionAnchorTag;    // The HTML anchor tag of the definition where the result was found
@property (atomic, readonly, copy) NSString *   phrase;                 // The search phrase
@property (atomic, readonly, copy) NSArray *    regexFoundGroups;       // Array of strings for the found regex groups
@property (atomic, getter=isWritingWithInformResult, readonly) bool writingWithInformResult;  // Is the result found in the WritingWithInform documentation?
@property (atomic, getter=isRecipeBookResult, readonly) bool recipeBookResult;                // Is the result found in the Recipe Book documentation?
@property (atomic, readonly, copy) NSAttributedString *attributedContext;

// Initialisation
-(instancetype)   init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;

-(instancetype)   initWithFilepath: (NSString*)       filepath
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
                  regexFoundGroups: (NSArray*)        aRegexFoundGroups NS_DESIGNATED_INITIALIZER;


- (void)            setError:(BOOL) hasError;
- (NSString*)       stringByReplacingGroups:(NSString*) replace;
+ (NSString*)       stringByReplacingGroups:(NSString*) replace regexFoundGroups:(NSArray*) aRegexFoundGroups;

@end
