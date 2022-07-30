//
//  IFDocParser.h
//  Inform
//
//  Created by Andrew Hunter on 28/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NSString *IFDocAttributeKey NS_STRING_ENUM;

extern IFDocAttributeKey const IFDocAttributeHtmlTitle;
extern IFDocAttributeKey const IFDocAttributeTitle;
extern IFDocAttributeKey const IFDocAttributeSection;
extern IFDocAttributeKey const IFDocAttributeSort;

///
/// Information about an example section foun in the HTML
///
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

///
/// Very simple HTML parser that deals with document files, extracting the text and any attributes,
/// suitable for use in a search.
///
@interface IFDocParser : NSObject

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
/// Parses the specified HTML, extracting attributes and the plain text version
- (instancetype) initWithHtml: (NSString*) html NS_DESIGNATED_INITIALIZER;

/// The plain text version of the file that has been parsed
@property (atomic, readonly, copy) NSString *plainText;
/// The attributes from the file that has been parsed
@property (atomic, readonly, copy) NSDictionary<IFDocAttributeKey,id> *attributes;
/// Dictionary of examples in the document. Keys are string version of example name, values are IFExampleInfo.
@property (atomic, readonly, copy) NSDictionary<NSString*,IFExampleInfo*> *exampleInfo;
/// Array of \c IFCodeInfo specifying ranges in the document where code occurs.
@property (atomic, readonly, copy) NSArray<IFCodeInfo*> *codeInfo;
/// Array of \c IFCodeInfo specifying ranges in the document where definitions occur.
@property (atomic, readonly, copy) NSArray<IFCodeInfo*> *definitionInfo;

@end
