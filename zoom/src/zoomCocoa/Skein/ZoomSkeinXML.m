//
//  ZoomSkeinXML.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkein.h"

#include <expat.h>

// = XML input class =

static NSString* xmlAttributes = @"xmlAttributes";
static NSString* xmlName	   = @"xmlName";
static NSString* xmlChildren   = @"xmlChildren";
static NSString* xmlType	   = @"xmlType";
static NSString* xmlChars      = @"xmlChars";

static NSString* xmlElement    = @"xmlElement";
static NSString* xmlCharData   = @"xmlCharData";

@interface ZoomSkeinXMLInput : NSObject {
	NSMutableDictionary* result;
	NSMutableArray*      xmlStack;
}

- (BOOL) processXML: (NSData*) xml;
- (NSDictionary*) processedXML;

- (NSDictionary*) childForElement: (NSDictionary*) element
						 withName: (NSString*) elementName;
- (NSArray*) childrenForElement: (NSDictionary*) element
					   withName: (NSString*) elementName;
- (NSString*) innerTextForElement: (NSDictionary*) element;
- (NSString*) attributeValueForElement: (NSDictionary*) element
							  withName: (NSString*) elementName;

@end

// = XML output functions =

static NSString* idForNode(ZoomSkeinItem* item) {
	// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node)
	return [NSString stringWithFormat: @"node-%p", item];
}

struct xmlEncodeState {
	int resLen;
	int maxLen;
	unichar* res;
};

static inline void append(unichar chr, struct xmlEncodeState* state) {
	while (state->resLen >= state->maxLen) {
		state->maxLen += 256;
		state->res = realloc(state->res, sizeof(unichar)*state->maxLen);
	}
	
	state->res[state->resLen++] = chr;
}

static inline void appendStr(NSString* str, struct xmlEncodeState* state) {
	int x;
	for (x=0; x<[str length]; x++) {
		append([str characterAtIndex: x], state);
	}
}

static NSString* xmlEncode(NSString* str) {
	int x;
	
	// Grr, Cocoa has no 'append character' thing in NSMutableString, which is daft
	// To avoid being slower than a turtle embedded in cement, do everything manually
	static struct xmlEncodeState state = { 0, 0, nil };
	
	state.resLen = 0;
	
	// Actually convert the string
	for (x=0; x<[str length]; x++) {
		unichar chr = [str characterAtIndex: x];
		
		if (chr == '\n') {
			append('\n', &state);
		} else if (chr == '&') {
			appendStr(@"&amp;", &state);
		} else if (chr == '<') {
			appendStr(@"&lt;", &state);
		} else if (chr == '>') {
			appendStr(@"&gt;", &state);
		} else if (chr == '"') {
			appendStr(@"&quot;", &state);
		} else if (chr == '\'') {
			appendStr(@"&apos;", &state);
		} else if (chr < 0x20) {
			// Ignore (expat can't parse these)
		} else {
			// NOTE/FIXME: Surrogate characters are not handled correctly
			// May, I suppose, cause a problem with chinese IF
			append(chr, &state);
		}
	}
	
	return [NSString stringWithCharacters: state.res
								   length: state.resLen];
}

@implementation ZoomSkein(ZoomSkeinXML)

// = XML data =

// Creating XML
- (NSString*) xmlData {
	// Structure summary (note to me: write this up properly later)
	
	// <Skein rootNode="<nodeID>" xmlns="http://www.logicalshift.org.uk/IF/Skein">
	//   <generator>Zoom</generator>
	//   <activeItem nodeId="<nodeID" />
	//   <item nodeId="<nodeID>">
	//     <command/>
	//     <result/>
	//     <annotation/>
	//	   <commentary/>
	//     <played>YES/NO</played>
	//     <changed>YES/NO</changed>
	//     <temporary score="score">YES/NO</temporary>
	//     <children>
	//       <child nodeId="<nodeID>"/>
	//     </children>
	//   </item>
	// </Skein>
	//
	// nodeIDs are string uniquely identifying a node: any format
	// A node must not be a child of more than one item
	// All item fields are optional.
	// Root item usually has the command '- start -'
	
	NSMutableString* result = [[[NSMutableString alloc] init] autorelease];
	
	// Write header
	[result appendFormat: 
		@"<Skein rootNode=\"%@\" xmlns=\"http://www.logicalshift.org.uk/IF/Skein\">\n",
			idForNode(rootItem)];
	[result appendString: @"  <generator>Zoom</generator>\n"];
	[result appendFormat: @"  <activeNode nodeId=\"%@\" />\n", idForNode(activeItem)];
	
	// Write items
	NSMutableArray* itemStack = [NSMutableArray array];
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop from the stack
		ZoomSkeinItem* node = [[itemStack lastObject] retain];
		[itemStack removeLastObject];
		
		// Push any children of this node
		NSEnumerator* childEnum = [[node children] objectEnumerator];
		ZoomSkeinItem* childNode;
		while (childNode = [childEnum nextObject]) {
			[itemStack addObject: childNode];
		}
		
		// Generate the XML for this node
		[result appendFormat: @"  <item nodeId=\"%@\">\n",
			idForNode(node)];
		
		if ([node command] != nil)
			[result appendFormat: @"    <command xml:space=\"preserve\">%@</command>\n",
				xmlEncode([node command])];
		if ([node result] != nil)
			[result appendFormat: @"    <result xml:space=\"preserve\">%@</result>\n",
				xmlEncode([node result])];
		if ([node annotation] != nil)
			[result appendFormat: @"    <annotation xml:space=\"preserve\">%@</annotation>\n",
				xmlEncode([node annotation])];
		if ([node commentary] != nil)
			[result appendFormat: @"    <commentary xml:space=\"preserve\">%@</commentary>\n",
				xmlEncode([node commentary])];
		
		[result appendFormat: @"    <played>%@</played>\n",
			[node played]?@"YES":@"NO"];
		[result appendFormat: @"    <changed>%@</changed>\n",
			[node changed]?@"YES":@"NO"];
		[result appendFormat: @"    <temporary score=\"%i\">%@</temporary>\n",
			[node temporaryScore], [node temporary]?@"YES":@"NO"];
		
		if ([[node children] count] > 0) {
			[result appendString: @"    <children>\n"];
			
			childEnum = [[node children] objectEnumerator];
			while (childNode = [childEnum nextObject]) {
				[result appendFormat: @"      <child nodeId=\"%@\" />\n",
					idForNode(childNode)];
			}
			
			[result appendString: @"    </children>\n"];
		}
		
		[result appendString: @"  </item>\n"];
		
		[node release];
	}
	
	// Write footer
	[result appendString: @"</Skein>\n"];
	
	return result;
}

// = Parsing the XML =

// Have to use expat: Apple's own XML parser is not available in Jaguar

- (BOOL) parseXmlData: (NSData*) data {
	NSAutoreleasePool* xmlAutorelease = [[NSAutoreleasePool alloc] init];
	
	ZoomSkeinXMLInput* inputParser = [[ZoomSkeinXMLInput alloc] init];
	
	// Process the XML associated with this file
	if (![inputParser processXML: data]) {
		// Failed to parse
		NSLog(@"ZoomSkein: Failed to parse skein XML data");
		
		[inputParser release];

		[xmlAutorelease release];
		return NO;
	}
	
	// Free up the XML data when we return
	[inputParser autorelease];
	
	// OK, actually process the data
	NSDictionary* skein = [inputParser childForElement: [inputParser processedXML]
											  withName: @"Skein"];
	
	if (skein == nil) {
		NSLog(@"ZoomSkein: Failed to find root 'Skein' element");

		[xmlAutorelease release];
		return NO;
	}
	
	// Header fields
	NSString* rootNodeId = [inputParser attributeValueForElement: skein
														withName: @"rootNode"];
	NSString* generator = [inputParser innerTextForElement: [inputParser childForElement: skein
																				withName: @"generator"]];
	NSString* activeNode = [inputParser attributeValueForElement: [inputParser childForElement: skein
																					  withName: @"activeNode"]
														withName: @"nodeId"];
	if (![generator isEqualToString: @"Zoom"]) {
		NSLog(@"ZoomSkein: XML file generated by %@", generator);
	}
	
	if (rootNodeId == nil) {
		NSLog(@"ZoomSkein: No root node ID specified");

		[xmlAutorelease release];
		return NO;
	}
	
	if (activeNode == nil) {
		NSLog(@"ZoomSkein: Warning: No active node specified");
	}
	
	// Item dictionary: populate with items ready to be linked together
	NSMutableDictionary* itemDictionary = [NSMutableDictionary dictionary];
	
	NSArray* items = [inputParser childrenForElement: skein
											withName: @"item"];
	
	NSEnumerator* itemEnum = [items objectEnumerator];
	NSDictionary* item;
	
	while (item = [itemEnum nextObject]) {
		NSString* itemNodeId = [inputParser attributeValueForElement: item
															withName: @"nodeId"];
		
		if (itemNodeId == nil) {
			NSLog(@"ZoomSkein: Warning - found item with no ID");
			continue;
		}
		
		ZoomSkeinItem* newItem = [[ZoomSkeinItem alloc] initWithCommand: @"- PLACEHOLDER -"];
		[itemDictionary setObject: newItem
						   forKey: itemNodeId];
		[newItem release];
	}
	
	// Item dictionary II: fill in the node data
	itemEnum = [items objectEnumerator];

	while (item = [itemEnum nextObject]) {
		NSString* itemNodeId = [inputParser attributeValueForElement: item
															withName: @"nodeId"];
		
		if (itemNodeId == nil) {
			continue;
		}
		
		ZoomSkeinItem* newItem = [itemDictionary objectForKey: itemNodeId];
		if (newItem == nil) {
			// Should never happen
			// (Hahaha)
			NSLog(@"ZoomSkein: Programmer is a spoon (item ID: %@)", itemNodeId);
			[xmlAutorelease release];
			return NO;
		}
		
		// Item info
		NSString* command = [inputParser innerTextForElement: [inputParser childForElement: item
																				  withName: @"command"]];
		NSString* result = [inputParser innerTextForElement: [inputParser childForElement: item
																				 withName: @"result"]];
		NSString* annotation = [inputParser innerTextForElement: [inputParser childForElement: item
																					 withName: @"annotation"]];
		NSString* commentary = [inputParser innerTextForElement: [inputParser childForElement: item
																					 withName: @"commentary"]];
		BOOL played = [[inputParser innerTextForElement: [inputParser childForElement: item
																			 withName: @"played"]] isEqualToString: @"YES"];
		BOOL changed = [[inputParser innerTextForElement: [inputParser childForElement: item
																			 withName: @"changed"]] isEqualToString: @"YES"];
		BOOL temporary = [[inputParser innerTextForElement: [inputParser childForElement: item
																				withName: @"temporary"]] isEqualToString: @"YES"];
		int  tempVal = [[inputParser attributeValueForElement: [inputParser childForElement: item
																				   withName: @"temporary"]
													 withName: @"score"] intValue];
		
		if (command == nil) {
			//NSLog(@"ZoomSkein: Warning: item with no command found");
			command = @"";
		}
		
		[newItem setCommand: command];
		[newItem setResult: result];
		[newItem setAnnotation: annotation];
		[newItem setCommentary: commentary];
		
		[newItem setPlayed: played];
		[newItem setChanged: changed];
		[newItem setTemporary: temporary];
		[newItem setTemporaryScore: tempVal];
	}
		
	// Item dictionary III: fill in the item children
	itemEnum = [items objectEnumerator];
	
	while (item = [itemEnum nextObject]) {		
		NSString* itemNodeId = [inputParser attributeValueForElement: item
															withName: @"nodeId"];
		
		if (itemNodeId == nil) {
			continue;
		}
		
		ZoomSkeinItem* newItem = [itemDictionary objectForKey: itemNodeId];
		if (newItem == nil) {
			// Should never happen
			// (Hahaha)
			NSLog(@"ZoomSkein: Programmer is a spoon (item ID: %@)", itemNodeId);
			[xmlAutorelease release];
			return NO;
		}

		// Item children
		NSArray* itemKids =[inputParser childrenForElement: [inputParser childForElement: item
																				withName: @"children"]
												  withName: @"child"];
		NSEnumerator* kidEnum = [itemKids objectEnumerator];
		NSDictionary* child;
		
		while (child = [kidEnum nextObject]) {
			NSString* kidNodeId = [inputParser attributeValueForElement: child
															   withName: @"nodeId"];
			if (kidNodeId == nil) {
				NSLog(@"ZoomSkein: Warning: Child item with no node id");
				continue;
			}
			
			ZoomSkeinItem* kidItem = [itemDictionary objectForKey: kidNodeId];
			
			if (kidItem == nil) {
				NSLog(@"ZoomSkein: Warning: unable to find node %@", kidNodeId);
				continue;
			}
			
			ZoomSkeinItem* newKid = [newItem addChild: kidItem];
			[itemDictionary setObject: newKid
							   forKey: kidNodeId];
		}
	}
	
	// Root item
	ZoomSkeinItem* newRoot = [itemDictionary objectForKey: rootNodeId];
	if (newRoot == nil) {
		NSLog(@"ZoomSkein: No root node");
		[xmlAutorelease release];
		return NO;
	}
	
	[rootItem release];
	rootItem = [newRoot retain];
	
	[activeItem release];
	if (activeNode != nil)
		activeItem = [[itemDictionary objectForKey: activeNode] retain];
	else
		activeItem = [rootItem retain];
	
	[self zoomSkeinChanged];

	[xmlAutorelease release];
	return YES;
}

@end

// = XML input helper class =

// For later, maybe: develop this into a class in it's own right?
// Would really want custom types for the XML tree, then

@implementation ZoomSkeinXMLInput

- (id) init {
	self = [super init];
	
	if (self) {
	}
	
	return self;
}

- (void) dealloc {
	[result release];
	[xmlStack release];
	
	[super dealloc];
}

// XML processing functions
static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts);
static XMLCALL void endElement  (void *userData,
								 const XML_Char *name);
static XMLCALL void charData    (void *userData,
								 const XML_Char *s,
								 int len);

- (BOOL) processXML: (NSData*) xml {
	// Setup our state
	[result release]; result = [[NSMutableDictionary alloc] init];
	[xmlStack release]; xmlStack = [[NSMutableArray alloc] init];
	
	// Initial element on the stack
	[xmlStack addObject: result];
	
	// Initialise the expat parser
	XML_Parser theParser;
	
	theParser = XML_ParserCreate(NULL);
	
	XML_SetElementHandler(theParser, startElement, endElement);
	XML_SetCharacterDataHandler(theParser, charData);
	XML_SetUserData(theParser, self);
	
	// Perform the parsing
	int status = XML_Parse(theParser, [xml bytes], [xml length], 1);
	
	// Tidy up the parser
	XML_ParserFree(theParser);
		
	// Abort here if the parser fails
	if (status != XML_STATUS_OK) return NO;
	
	return YES;
}

- (NSDictionary*) processedXML {
	return result;
}

// In the DOM, would iterate. Doesn't here (shouldn't matter)
- (NSString*) innerTextForElement: (NSDictionary*) element {
	NSMutableString* res = nil;
	
	NSEnumerator* children = [[element objectForKey: xmlChildren] objectEnumerator];
	NSDictionary* child;
	
	while (child = [children nextObject]) {
		if ([[child objectForKey: xmlType] isEqualToString: xmlCharData]) {
			if (res == nil) {
				res = [[NSMutableString alloc] initWithString: [child objectForKey: xmlChars]];
			} else {
				[res appendString: [child objectForKey: xmlChars]];
			}
		}
	}
	
	return [res autorelease];
}

- (NSArray*) childrenForElement: (NSDictionary*) element
					   withName: (NSString*) elementName {
	NSMutableArray* res = nil;
	
	NSEnumerator* children = [[element objectForKey: xmlChildren] objectEnumerator];
	NSDictionary* child;
	
	while (child = [children nextObject]) {
		if ([[child objectForKey: xmlType] isEqualToString: xmlElement] &&
			[[child objectForKey: xmlName] isEqualToString: elementName]) {
			if (res == nil) {
				res = [[NSMutableArray alloc] init];
			}
			
			[res addObject: child];
		}
	}
	
	return [res autorelease];
}

- (NSDictionary*) childForElement: (NSDictionary*) element
						 withName: (NSString*) elementName {
	NSEnumerator* children = [[element objectForKey: xmlChildren] objectEnumerator];
	NSDictionary* child;
	
	while (child = [children nextObject]) {
		if ([[child objectForKey: xmlType] isEqualToString: xmlElement] &&
			[[child objectForKey: xmlName] isEqualToString: elementName]) {
			return child;
		}
	}
	
	return nil;
}

- (NSString*) attributeValueForElement: (NSDictionary*) element
							  withName: (NSString*) elementName {
	return [[element objectForKey: xmlAttributes] objectForKey: elementName];
}

// = XML callback messages =

static int Xstrlen(const XML_Char* a) {
	int x;
	
	if (a == NULL) return 0;
	
	for (x=0; a[x] != 0; x++);
	
	return x;
}

static unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};

static unichar* Xmdchar(const XML_Char* s, int len) {
	/* Converts s to unichars. Result needs to be freed */
	int x, pos;
	unichar* res;
	
	res = malloc(sizeof(unichar)*(len+1));
	pos = 0;
	
	for (x=0; x<len; x++) {
		int chr = (unsigned char)s[x];
		
		if (chr < 127) {
			res[pos++] = chr;
		} else {
			/* UTF-8 decode */
			int bytes = bytesFromUTF8[chr];
			int chrs[6];
			int y;
			int errorFlag;
			
			if (x+bytes >= len) break;
			
			/* Read+check the characters that make up this char */
			errorFlag = 0;
			for (y=0; y<=bytes; y++) {
				chrs[y] = (unsigned char)s[x+y];
				
				if (chrs[y] < 127) errorFlag = 1;
			}
			if (errorFlag) continue; /* Ignore this character (error) */
			
			/* Get the UCS-4 character */
			switch (bytes) {
				case 1: chr = ((chrs[0]&~0xc0)<<6)|(chrs[1]&~0x80); break;
				case 2: chr = ((chrs[0]&~0xe0)<<12)|((chrs[1]&~0x80)<<6)|(chrs[2]&~0x80); break;
				case 3: chr = ((chrs[0]&~0xf0)<<18)|((chrs[1]&~0x80)<<12)|((chrs[2]&~0x80)<<6)|(chrs[3]&~0x80); break;
				case 4: chr = ((chrs[0]&~0xf8)<<24)|((chrs[1]&~0x80)<<18)|((chrs[2]&~0x80)<<12)|((chrs[3]&~0x80)<<6)|(chrs[4]&~0x80); break;
				case 5: chr = ((chrs[0]&~0xfc)<<28)|((chrs[1]&~0x80)<<24)|((chrs[2]&~0x80)<<18)|((chrs[3]&~0x80)<<12)|((chrs[4]&~0x80)<<6)|(chrs[5]&~0x80); break;
			}
			
			x += bytes;
			
			res[pos++] = chr;
		}
	}
	
	res[pos] = 0;
	
	return res;
}

static NSString* makeString(const XML_Char* data) {
	unichar* res = Xmdchar(data, Xstrlen(data));
	
	int len;
	for (len=0; res[len]!=0; len++);
	
	NSString* str = [NSString stringWithCharacters: res
											length: len];
	free(res);
	
	return str;
}

static NSString* makeStringLen(const XML_Char* data, int lenIn) {
	unichar* res = Xmdchar(data, lenIn);
	
	int len;
	for (len=0; res[len]!=0; len++);
	
	NSString* str = [NSString stringWithCharacters: res
											length: len];
	free(res);
	
	return str;
}

- (void) startElement: (const XML_Char*) name
	   withAttributes: (const XML_Char**) atts {
	// Create this element
	NSMutableDictionary* lastElement = [xmlStack lastObject];
	NSMutableDictionary* element = [NSMutableDictionary dictionary];

	[element setObject: xmlElement
				forKey: xmlType];
	[element setObject: makeString(name)
				forKey: xmlName];
	
	// Attributes
	if (atts != NULL) {
		NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
		
		int x;
		for (x=0; atts[x] != NULL; x+=2) {
			[attributes setObject: makeString(atts[x+1])
						   forKey: makeString(atts[x])];
		}
		
		[element setObject: attributes
					forKey: xmlAttributes];
	}
	
	// Add as a child of the previous element
	NSMutableArray* children = [lastElement objectForKey: xmlChildren];
	if (children == nil) {
		children = [NSMutableArray array];
		[lastElement setObject: children
						forKey: xmlChildren];
	}
	[children addObject: element];
	
	// Push this element
	[xmlStack addObject: element];
}

- (void) endElement: (const XML_Char*) name {
	// Pop the last element
	[xmlStack removeLastObject];
}

- (void) charData: (const XML_Char*) s
	   withLength: (int) len {
	if (len <= 0) return;
	
	// Create this element
	NSMutableDictionary* lastElement = [xmlStack lastObject];
	NSMutableArray* children = [lastElement objectForKey: xmlChildren];
	NSMutableDictionary* element;
	BOOL addAsChild;
	
	if (children && [[[children lastObject] objectForKey: xmlType] isEqualToString: xmlCharData]) {
		element = [children lastObject];
		[[element objectForKey: xmlChars] appendString: makeStringLen(s, len)];
		
		addAsChild = NO;
	} else {
		element = [NSMutableDictionary dictionary];
		
		[element setObject: xmlCharData
					forKey: xmlType];
		[element setObject: [[makeStringLen(s, len) mutableCopy] autorelease]
					forKey: xmlChars];
		
		addAsChild = YES;
	}
	
	// Add as a child of the previous element, if required
	if (addAsChild) {
		if (children == nil) {
			children = [NSMutableArray array];
			[lastElement setObject: children
						forKey: xmlChildren];
		}
		[children addObject: element];
	}
}

// = XML callback implementation =

static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	[(ZoomSkeinXMLInput*)userData startElement: name
								withAttributes: atts];
}

static XMLCALL void endElement(void *userData,
								 const XML_Char *name) {
	[(ZoomSkeinXMLInput*)userData endElement: name];
}

static XMLCALL void charData(void *userData,
							 const XML_Char *s,
							 int len) {
	[(ZoomSkeinXMLInput*)userData charData: s
								withLength: len];
}

@end

