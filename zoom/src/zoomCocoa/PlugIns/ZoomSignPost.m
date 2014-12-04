//
//  ZoomSignPost.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomSignPost.h"
#import "ZoomStoryID.h"


@implementation ZoomSignPost

// = Initialising =

- (id) initWithData: (NSData*) data {
	self = [super init];
	
	if (self) {
		if (![self parseData: data]) {
			[self autorelease];
			return nil;
		}
	}
	
	return self;
}

- (BOOL) parseData: (NSData*) data {
	// Reset the state of this object
	[ifids release];					ifids					= nil;
	[interpreterDisplayName release];	interpreterDisplayName	= nil;
	[interpreterURL release];			interpreterURL			= nil;
	[interpreterVersion release];		interpreterVersion		= nil;
	[pluginVersion release];			pluginVersion			= nil;
	[downloadURL release];				downloadURL				= nil;
	[errorMessage release];				errorMessage			= nil;
	
	reparseAsPlist = NO;
	parseError = NO;
	
	[pathStack release];				pathStack	= [[NSMutableArray alloc] init];
	[cDataStack release];				cDataStack	= [[NSMutableArray alloc] init];
	
	// Begin parsing
	NSXMLParser* parser = [[[NSXMLParser alloc] initWithData: data] autorelease];
	[parser setDelegate: self];
	
	[parser parse];
	if (parseError && !reparseAsPlist) return NO;
	
	// Reparse as a plist if requested
	if (reparseAsPlist) {
		NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: data
																mutabilityOption: NSPropertyListImmutable
																		  format: nil
																errorDescription: nil];
		if (!plist) return NO;
		if (![plist isKindOfClass: [NSDictionary class]]) return NO;
		
		[ifids release]; 
		ifids = [[NSArray arrayWithObjects: [plist objectForKey: @"IFID"], nil] mutableCopy];
		[interpreterDisplayName release];
		[interpreterURL release];
		[interpreterVersion release];
		[pluginVersion release];
		[downloadURL release];
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

// = Parsing =

- (void)  parser: (NSXMLParser *)parser 
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
	[cDataStack addObject: [[@"" mutableCopy] autorelease]];
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
	NSMutableString* pathString = [[@"" mutableCopy] autorelease];
	NSEnumerator* pathEnum = [pathStack objectEnumerator];
	NSString* pathComponent;
	while (pathComponent = [pathEnum nextObject]) {
		[pathString appendString: @"/"];
		[pathString appendString: pathComponent];
	}
	
	pathString = [[[pathString lowercaseString] mutableCopy] autorelease];
	
	// Perform an action if this is a recognised path string
	if ([pathString isEqualToString: @"/autoinstall/ifids/ifid"]) {
		
		if (!ifids) ifids = [[NSMutableArray alloc] init];
		[ifids addObject: [cData stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/href"]) {
		
		[downloadURL release];
		downloadURL = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/displayname"]) {
		
		[interpreterDisplayName release];
		interpreterDisplayName = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/url"]) {
		
		[interpreterURL release];
		interpreterURL = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/interpreterversion"]) {
		
		[interpreterVersion release];
		interpreterVersion = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/download/game/format/interpreter/plugin/version"]) {
		
		[pluginVersion release];
		pluginVersion = [cData copy];
		
	} else if ([pathString isEqualToString: @"/autoinstall/error/message"]) {
		
		[errorMessage release];
		errorMessage = [cData copy];
		
	}
	
	// Finish up: pop from the path stack and the cData stack
	[cDataStack removeLastObject];
	[pathStack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)theParseError {
	parseError = YES;
}

// = Getting signpost data =

- (NSArray*) ifids {
	NSMutableArray* result = [NSMutableArray array];
	
	NSEnumerator* ifidEnum = [ifids objectEnumerator];
	NSString* idString;
	while (idString = [ifidEnum nextObject]) {
		[result addObject: [[ZoomStoryID alloc] initWithIdString: idString]];
	}
	
	return result;
}

- (NSString*) interpreterDisplayName {
	return interpreterDisplayName;
}

- (NSURL*) interpreterURL {
	if (!interpreterURL) return nil;
	return [NSURL URLWithString: interpreterURL];
}

- (NSString*) interpreterVersion {
	return interpreterVersion;
}

- (NSString*) pluginVersion {
	return pluginVersion;
}

- (NSURL*) downloadURL {
	if (!downloadURL) return nil;
	return [NSURL URLWithString: downloadURL];
}

- (NSString*) errorMessage {
	return errorMessage;
}

// = Serializing =

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
	
	return [NSPropertyListSerialization dataFromPropertyList: plist
													  format: NSPropertyListXMLFormat_v1_0
											errorDescription: nil];
}

@end
