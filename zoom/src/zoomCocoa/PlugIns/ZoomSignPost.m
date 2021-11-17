//
//  ZoomSignPost.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomSignPost.h"
#import "ZoomStoryID.h"


@implementation ZoomSignPost {
	// The signpost data
	NSMutableArray<NSString*>* ifids;
	NSString* interpreterDisplayName;
	NSString* interpreterURL;
	NSString* interpreterVersion;
	NSString* pluginVersion;
	NSString* downloadURL;
	NSString* errorMessage;
	
	// Parsing state
	BOOL reparseAsPlist;
	BOOL parseError;
	NSMutableArray<NSString*>* pathStack;
	NSMutableArray<NSMutableString*>* cDataStack;
}

#pragma mark - Initialising

- (id) initWithData: (NSData*) data {
	self = [super init];
	
	if (self) {
		if (![self parseData: data]) {
			return nil;
		}
	}
	
	return self;
}

- (BOOL) parseData: (NSData*) data {
	// Reset the state of this object
	ifids					= nil;
	interpreterDisplayName	= nil;
	interpreterURL			= nil;
	interpreterVersion		= nil;
	pluginVersion			= nil;
	downloadURL				= nil;
	errorMessage			= nil;
	
	reparseAsPlist = NO;
	parseError = NO;
	
	pathStack	= [[NSMutableArray alloc] init];
	cDataStack	= [[NSMutableArray alloc] init];
	
	// Begin parsing
	NSXMLParser* parser = [[NSXMLParser alloc] initWithData: data];
	[parser setDelegate: self];
	
	[parser parse];
	if (parseError && !reparseAsPlist) return NO;
	
	// Reparse as a plist if requested
	if (reparseAsPlist) {
		NSDictionary* plist = [NSPropertyListSerialization propertyListWithData: data
																		options: NSPropertyListImmutable
																		 format: nil
																		  error: nil];
		if (!plist) return NO;
		if (![plist isKindOfClass: [NSDictionary class]]) return NO;
		
		ifids = [NSMutableArray arrayWithObject: [plist objectForKey: @"IFID"]];
		interpreterDisplayName	= [[plist objectForKey: @"Interpreter"] copy];
		interpreterURL			= [[plist objectForKey: @"InterpreterURL"] copy];
		interpreterVersion		= [[plist objectForKey: @"InterpreterVersion"] copy];
		pluginVersion			= [[plist objectForKey: @"PluginVersion"] copy];
		downloadURL				= [[plist objectForKey: @"URL"] copy];
	}

	// Check that we have the minimal properties required of a valid signpost
	if (errorMessage) return YES;
	if (!downloadURL || [downloadURL length] <= 0) return NO;
	
	return YES;
}

#pragma mark - Parsing

- (void)  parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI 
   qualifiedName:(NSString *)qualifiedName 
	  attributes:(NSDictionary *)attributeDict {
	// If the root element is 'plist', then reparse the file as a property list
	if ([pathStack count] == 0 && [elementName isEqualToString: @"plist"]) {
		[parser abortParsing];
		reparseAsPlist = YES;
	}
	
	// Push this element on to the path stack
	[pathStack addObject: elementName];
	[cDataStack addObject: [NSMutableString string]];
}

- (void)   parser:(NSXMLParser *)parser 
  foundCharacters:(NSString *)string {
	if ([cDataStack count] <= 0) return;
	
	// Append to the topmost cdata block
	[[cDataStack lastObject] appendString: string];
}

- (void)   parser:(NSXMLParser *)parser 
	didEndElement:(NSString *)elementName 
	 namespaceURI:(NSString *)namespaceURI 
	qualifiedName:(NSString *)qName {
	if ([pathStack count] <= 0) return;
	
	// Get the character data for this element
	NSString* cData = [cDataStack lastObject];
	
	// Build up the path string
	NSMutableString* pathString = [NSMutableString string];
	NSEnumerator* pathEnum = [pathStack objectEnumerator];
	for (NSString* pathComponent in pathEnum) {
		[pathString appendString: @"/"];
		[pathString appendString: pathComponent];
	}
	
	pathString = [[pathString lowercaseString] mutableCopy];
	
	// Perform an action if this is a recognised path string
	if ([pathString isEqualToString: @"/autoinstall/ifids/ifid"]) {
		
		if (!ifids) ifids = [[NSMutableArray alloc] init];
		[ifids addObject: [cData stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/href"]) {
		
		downloadURL = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/displayname"]) {
		
		interpreterDisplayName = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/url"]) {
		
		interpreterURL = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/interpreterversion"]) {
		
		interpreterVersion = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/version"]) {
		
		pluginVersion = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/error/message"]) {
		
		errorMessage = [cData copy];
		
	}
	
	// Finish up: pop from the path stack and the cData stack
	[cDataStack removeLastObject];
	[pathStack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)theParseError {
	parseError = YES;
}

#pragma mark - Getting signpost data

- (NSArray*) ifids {
	NSMutableArray* result = [NSMutableArray array];
	
	for (NSString* idString in ifids) {
		[result addObject: [[ZoomStoryID alloc] initWithIdString: idString]];
	}
	
	return [result copy];
}

@synthesize interpreterDisplayName;

- (NSURL*) interpreterURL {
	if (!interpreterURL) return nil;
	return [NSURL URLWithString: interpreterURL];
}

@synthesize interpreterVersion;
@synthesize pluginVersion;

- (NSURL*) downloadURL {
	if (!downloadURL) return nil;
	return [NSURL URLWithString: downloadURL];
}

@synthesize errorMessage;

#pragma mark - Serializing

- (NSData*) data {
	NSMutableDictionary* plist = [NSMutableDictionary dictionary];
	
	if ([ifids count] > 0) {
		[plist setObject: [ifids objectAtIndex: 0]
				  forKey: @"IFID"];
	}
	if (interpreterDisplayName) {
		[plist setObject: interpreterDisplayName
				  forKey: @"Interpreter"];
	}
	if (interpreterURL) {
		[plist setObject: interpreterURL
				  forKey: @"InterpreterURL"];
	}
	if (interpreterVersion) {
		[plist setObject: interpreterVersion
				  forKey: @"InterpreterVersion"];
	}
	if (pluginVersion) {
		[plist setObject: pluginVersion
				  forKey: @"PluginVersion"];
	}
	if (downloadURL) {
		[plist setObject: downloadURL
				  forKey: @"URL"];
	}
	
	return [NSPropertyListSerialization dataWithPropertyList: plist
													  format: NSPropertyListXMLFormat_v1_0
													 options: 0
													   error: nil];
}

@end
