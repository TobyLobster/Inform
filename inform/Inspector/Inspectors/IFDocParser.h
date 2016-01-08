//
//  IFDocParser.h
//  Inform
//
//  Created by Andrew Hunter on 28/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* IFDocHtmlTitleAttribute;
extern NSString* IFDocTitleAttribute;
extern NSString* IFDocSectionAttribute;
extern NSString* IFDocSortAttribute;

//
// Information about an example section foun in the HTML
//
@interface IFExampleInfo : NSObject

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithName:(NSString*) aName anchorTag:(NSString*) aAnchorTag range:(NSRange)aRange NS_DESIGNATED_INITIALIZER;
@property (atomic, readonly, copy) NSString *name;
@property (atomic, readonly, copy) NSString *anchorTag;
@property (atomic, readonly) NSRange range;

@end

@interface IFCodeInfo : NSObject

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithAnchorTag:(NSString*) aAnchorTag range:(NSRange)aRange NS_DESIGNATED_INITIALIZER;
@property (atomic, readonly, copy) NSString *anchorTag;
@property (atomic, readonly) NSRange range;

@end

//
// Very simple HTML parser that deals with document files, extracting the text and any attributes,
// suitable for use in a search.
//
@interface IFDocParser : NSObject

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithHtml: (NSString*) html NS_DESIGNATED_INITIALIZER;		// Parses the specified HTML, extracting attributes and the plain text version

@property (atomic, readonly, copy) NSString *plainText;					// The plain text version of the file that has been parsed
@property (atomic, readonly, copy) NSDictionary *attributes;				// The attributes from the file that has been parsed
@property (atomic, readonly, copy) NSDictionary *exampleInfo;              // Dictionary of examples in the document. Keys are string version of example name, values are IFExampleInfo.
@property (atomic, readonly, copy) NSArray *codeInfo;                      // Array of IFCodeInfo specifying ranges in the document where code occurs.
@property (atomic, readonly, copy) NSArray *definitionInfo;                // Array of IFCodeInfo specifying ranges in the document where definitions occur.

@end
