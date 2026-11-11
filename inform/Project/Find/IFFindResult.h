//
//  IFFindResult.h
//  Inform
//
//  Created by Andrew Hunter on 17/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

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
@interface IFFindResult : NSObject

// Data
/// The filepath of the file in which the result was found
@property (atomic, readonly, copy, nullable) NSString *   filepath;
/// The range within the file of the match
@property (atomic, readonly)                 NSRange      fileRange;
/// The document name diaplyed in the results
@property (atomic, readonly, copy, nullable) NSString *   documentDisplayName;
/// Name used for sorting the results into order
@property (atomic, readonly, copy, nullable) NSString *   documentSortName;
/// The location type of the match
@property (atomic, readonly)                 IFFindLocation locationType;
/// The context the match was found in
@property (atomic, readonly, copy)           NSString *   context;
/// The range in the context of the match
@property (atomic, readonly)                 NSRange      contextRange;
/// The name of the example where it was found
@property (atomic, readonly, copy, nullable) NSString *   exampleName;
/// The HTML anchor tag of the example where the result was found
@property (atomic, readonly, copy, nullable) NSString *   exampleAnchorTag;
/// The HTML anchor tag of the code where the result was found
@property (atomic, readonly, copy, nullable) NSString *   codeAnchorTag;
/// The HTML anchor tag of the definition where the result was found
@property (atomic, readonly, copy, nullable) NSString *   definitionAnchorTag;
/// The search phrase
@property (atomic, readonly, copy)           NSString *   phrase;
/// Array of strings for the found regex groups
@property (atomic, readonly, copy, nullable) NSArray<NSString*> * regexFoundGroups;
/// Is the result found in the Recipe Book documentation?
@property (atomic, getter=isRecipeBookResult, readonly) bool recipeBookResult;
/// Is the result found in one of the documentation's examples, each a page of its own?
@property (atomic, getter=isExampleResult, readonly) bool exampleResult;

@property (atomic, readonly, copy) NSAttributedString *attributedContext;

// Initialisation
-(instancetype)   init NS_UNAVAILABLE;

-(instancetype)   initWithFilepath: (nullable NSString*)   filepath
                       rangeInFile: (NSRange)             fileRange
               documentDisplayName: (nullable NSString*)   documentDisplayName
                  documentSortName: (nullable NSString*)   documentSortName
                      locationType: (IFFindLocation)      locationType
                           context: (NSString*)           context
                      contextRange: (NSRange)             contextRange
                       exampleName: (nullable NSString*)   aExampleName
                  exampleAnchorTag: (nullable NSString*)   aExampleAnchorTag
                     codeAnchorTag: (nullable NSString*)   aCodeAnchorTag
               definitionAnchorTag: (nullable NSString*)   aDefinitionAnchorTag
                  regexFoundGroups: (nullable NSArray<NSString*>*) aRegexFoundGroups NS_DESIGNATED_INITIALIZER;


- (void)            setError:(BOOL) hasError;
- (NSString*)       stringByReplacingGroups:(NSString*) replace;
+ (NSString*)       stringByReplacingGroups:(NSString*) replace regexFoundGroups:(nullable NSArray<NSString*>*) aRegexFoundGroups;

@end

NS_ASSUME_NONNULL_END
