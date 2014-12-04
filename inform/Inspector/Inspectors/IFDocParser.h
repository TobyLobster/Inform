//
//  IFDocParser.h
//  Inform-xc2
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
@interface IFExampleInfo : NSObject {
    NSString*   name;
    NSString*   anchorTag;
    NSRange     range;
};

-(id) initWithName:(NSString*) aName anchorTag:(NSString*) aAnchorTag range:(NSRange)aRange;
-(NSString *) name;
-(NSString *) anchorTag;
-(NSRange) range;

@end

@interface IFCodeInfo : NSObject {
    NSString*   anchorTag;
    NSRange     range;
};

-(id) initWithAnchorTag:(NSString*) aAnchorTag range:(NSRange)aRange;
-(NSString *) anchorTag;
-(NSRange) range;

@end

//
// Very simple HTML parser that deals with document files, extracting the text and any attributes,
// suitable for use in a search.
//
@interface IFDocParser : NSObject {
	// The parse results
	NSString*       plainText;				// The plain text version of the HTML document
	NSDictionary*   attributes;             // The attributes associated with the HTML document
    NSDictionary*   exampleInfo;            // Dictionary of examples in the document. Keys are string version of example name, values are IFExampleInfo.
    NSArray*        codeInfo;               // Array of IFCodeInfo specifying ranges in the document where code occurs.
    NSArray*        definitionInfo;         // Array of IFCodeInfo specifying ranges in the document where definitions occur.
}

- (id) initWithHtml: (NSString*) html;		// Parses the specified HTML, extracting attributes and the plain text version

- (NSString*) plainText;					// The plain text version of the file that has been parsed
- (NSDictionary*) attributes;				// The attributes from the file that has been parsed
- (NSDictionary*) exampleInfo;              // Dictionary of examples in the document. Keys are string version of example name, values are IFExampleInfo.
- (NSArray*) codeInfo;                      // Array of IFCodeInfo specifying ranges in the document where code occurs.
- (NSArray*) definitionInfo;                // Array of IFCodeInfo specifying ranges in the document where definitions occur.

@end
