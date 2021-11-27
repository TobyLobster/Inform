//
//  IFJSProject.m
//  Inform
//
//  Created by Andrew Hunter on 29/08/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFJSProject.h"
#import "IFExtensionsManager.h"
#import "IFUtility.h"
#import "IFSourcePage.h"
#import "IFProjectPolicy.h"
#import "IFProjectController.h"
#import "IFAppDelegate.h"
#import <CommonCrypto/CommonDigest.h>       // md5 hash

@implementation IFJSProject {
    __weak IFProjectPane* pane;
}

// = Initialisation =

- (instancetype) initWithPane: (IFProjectPane*) newPane {
	self = [super init];
	
	if (self) {
		pane = newPane;
	}
	
	return self;
}

- (void) dealloc {
	pane = nil;	
}

// = JavaScript names for our selectors =

+ (NSString *) webScriptNameForSelector: (SEL)sel {
	if (sel == @selector(selectView:)) {
		return @"selectView";
	} else if (sel == @selector(createNewProject:story:)) {
		return @"createNewProject";
	} else if (sel == @selector(pasteCode:)) {
		return @"pasteCode";
	} else if (sel == @selector(openFile:)) {
		return @"openFile";
	} else if (sel == @selector(openUrl:)) {
		return @"openUrl";
	} else if (sel == @selector(askInterfaceForLocalVersionAuthor:title:available:)) {
		return @"askInterfaceForLocalVersion";
	} else if (sel == @selector(askInterfaceForLocalVersionTextAuthor:title:)) {
		return @"askInterfaceForLocalVersionText";
	} else if (sel == @selector(askInterfaceForMD5HashAuthor:title:)) {
        return @"askInterfaceForMD5Hash";
    } else if (sel == @selector(downloadMultipleExtensions:)) {
        return @"downloadMultipleExtensions";
    }
	
	return nil;
}

+ (BOOL) isSelectorExcludedFromWebScript: (SEL)sel {
	if (  sel == @selector(selectView:) 
		|| sel == @selector(createNewProject:story:)
		|| sel == @selector(pasteCode:)
		|| sel == @selector(openFile:)
		|| sel == @selector(openUrl:)
        || sel == @selector(askInterfaceForLocalVersionAuthor:title:available:)
        || sel == @selector(askInterfaceForLocalVersionTextAuthor:title:)
        || sel == @selector(askInterfaceForMD5HashAuthor:title:)
        || sel == @selector(downloadMultipleExtensions:)) {
		return NO;
	}
	
	return YES;
}

// = JavaScript operations on the pane =

- (void) selectView: (NSString*) view {
	view = [view lowercaseString];
	
	if ([view isEqualToString: @"source"]) {
		[pane selectViewOfType: IFSourcePane];
	} else if ([view isEqualToString: @"error"]) {
		[pane selectViewOfType: IFErrorPane];
	} else if ([view isEqualToString: @"game"]) {
		[pane selectViewOfType: IFGamePane];
	} else if ([view isEqualToString: @"documentation"]) {
		[pane selectViewOfType: IFDocumentationPane];
	} else if ([view isEqualToString: @"index"]) {
		[pane selectViewOfType: IFIndexPane];
	} else if ([view isEqualToString: @"skein"]) {
		[pane selectViewOfType: IFSkeinPane];
	} else {
		// Other view types are not supported at present
	}
}

static int valueForHexChar(unichar c) {
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	
	return 0;
}

- (NSString*) unescapeString: (NSString*) string {
	// Change '\n', '\t', etc marks in a string to newlines, tabs, etc
	int length = (int) [string length];
	if (length == 0) return @"";

	int outLength = -1;
	int totalLength = 256;
	unichar* newString = malloc(sizeof(unichar)*totalLength);

	int chNum;
	for (chNum = 0; chNum < length; chNum++) {
		// Get the next character
		unichar chr = [string characterAtIndex: chNum];
		unichar outChar = '?';
		
		// If it's an escape character, parse as appropriate
		if (chr == '\\' && chNum+1<length) {
			// The result depends on the next character
			chNum++;
			unichar nextChar = [string characterAtIndex: chNum];
			
			switch (nextChar) {
				case 'n':
					// Newline
					outChar = 10;
					break; 
					
				case 'r':
					// Return
					outChar = 13;
					break;
						
				case 't':
					// Tab
					outChar = 9;
					break;
					
				default:
					// Default behaviour is just to strip the '\'
					outChar = nextChar;
			}
		} else if (chr == '[' && chNum+1 < length) {
			// [=0xffff=] = exact character
			// (different versions of webkit treat the '\' character differently, so we need this to ensure that we get consistent results)
			unichar nextChar = [string characterAtIndex: chNum+1];
			if (nextChar == '=') {
				// [= matched: look for the matching =]
				unichar previous = nextChar;
				int finalChNum;
				for (finalChNum = chNum+1; finalChNum < length; finalChNum++) {
					unichar mightBeLast = [string characterAtIndex: finalChNum];
					
					if (previous == '=' && mightBeLast == ']') {
						break;
					}
					
					previous = mightBeLast;
				}
				
				// Get the character number from the string
				NSString* characterString = [string substringWithRange: NSMakeRange(chNum+2, finalChNum-chNum-3)];
				
				if ([characterString hasPrefix: @"0x"]) {
					// Is a hexidecimal character
					int val = 0;
					int pos;
					for (pos=2; pos<[characterString length]; pos++) {
						val *= 16;
						val += valueForHexChar([characterString characterAtIndex: pos]);
					}
					outChar = val;
				} else if ([characterString isEqualToString: @"BACK"]) {
					// Backslash
					outChar = '\\';
				} else {
					outChar = '?';
				}
				
				// Move to the final character
				chNum = finalChNum;
			} else {
				outChar = chr;
			}
		} else {
			// Otherwise, just pass it through
			outChar = chr;
		}
		
		// Add to the output string
		outLength++;
		if (outLength >= totalLength) {
			totalLength += 256;
			newString = realloc(newString, sizeof(unichar)*totalLength);
		}
		
		newString[outLength] = outChar;
	}
	
	// Turn newString into an NSString
	outLength++;
	NSString* result = [NSString stringWithCharacters: newString
											   length: outLength];
	free(newString);
	
	return result;
}

- (void) createNewProject: (NSString *)title
                    story: (NSString *)story {
    title = [self unescapeString: title];
    story = [self unescapeString: story];

	[(IFAppDelegate *) [NSApp delegate] createNewProject: title
                                 story: story];
}

- (void) pasteCode: (NSString*) code {
	[[pane sourcePage] pasteSourceCode: [self unescapeString: code]];
}

- (void) openFile: (NSString*) filename {
	[[NSWorkspace sharedWorkspace] openFile: filename];
}

- (void) openUrl: (NSString*) url {
	if (![[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: url]]) {
		NSLog(@"Could not open URL: %@", url);
	}
}

-(NSString*) askInterfaceForLocalVersionAuthor: (NSString*) author
                                         title: (NSString*) title
                                     available: (NSString*) availableVersion {
	IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = [author lowercaseString];
    title = [title lowercaseString];

	for( IFExtensionInfo* info in [mgr availableExtensions] ) {
        // NSLog(@"Got installed extension %@ by %@", [info title], info.author);
        if( [[info.author lowercaseString] isEqualToString: author] ) {
            if( [[[IFExtensionInfo canonicalTitle:info.displayName] lowercaseString] isEqualToString: title] ) {
                // We have this extension
                if( info.isBuiltIn ) {
                    //NSLog(@"Found %@ by %@ BUILT IN", title, author);
                    return @"!";
                }

                NSString* version = [info safeVersion];

                NSComparisonResult result = [version compare: availableVersion
                                                     options: (NSStringCompareOptions) (NSNumericSearch | NSCaseInsensitiveSearch) ];
                if( result == NSOrderedSame) {
                    //NSLog(@"Found %@ by %@ version %@ EQUAL", title, author, version);
                    return @"=";
                }
                if( result == NSOrderedAscending ) {
                    //NSLog(@"Found %@ by %@ version %@ <", title, author, version);
                    return @"<";
                }
                //NSLog(@"Found %@ by %@ version %@ >", title, author, version);
                return @">";
            }
        }
    }

    // Not found
    //NSLog(@"Looked for %@ by %@ NOT-FOUND", title, author);
    return @"";
}

-(NSString*) askInterfaceForLocalVersionTextAuthor: (NSString*) author
                                             title: (NSString*) title {
	IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = [author lowercaseString];
    title = [title lowercaseString];
    
	for( IFExtensionInfo* info in [mgr availableExtensions] ) {
        if( [[info.author lowercaseString] isEqualToString: author] ) {
            if( [[[IFExtensionInfo canonicalTitle: info.displayName] lowercaseString] isEqualToString: title] ) {
                return [info safeVersion];
            }
        }
    }

    // Not found
    return @"";
}

-(NSString*) askInterfaceForMD5HashAuthor: (NSString*) author
                                    title: (NSString*) title {
    // Not used yet
    return @"";
}

-(NSArray*) arrayFromWebScriptObject:(WebScriptObject*) object {
    id lengthObject = [object valueForKey:@"length"];
    unsigned length = [lengthObject isKindOfClass:[NSNumber class]] ? [lengthObject unsignedIntValue] : 0;
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:length];
    unsigned i;
    for (i = 0; i < length; ++i) {
        id element = [object webScriptValueAtIndex:i];
        if (element)
            [array addObject:element];
    }
    //NSLog(@"array filled with %u elements !", [array count]);
    return array;
}

-(void) downloadMultipleExtensions:(WebScriptObject*) object {
    NSArray* array = [self arrayFromWebScriptObject: object];

    for(int index = 0; index < [array count]; index += 3) {
        NSString* item      = array[index];
        NSString* urlString = array[index + 1];
        //NSString* version   = [array objectAtIndex: index + 2];
        //NSLog(@"item is %@ for url %@ version %@", item, urlString, version);

        NSURL* frameURL = [IFUtility publicLibraryURL];
        NSURL* realURL = [IFProjectPolicy urlFromLibraryURL: [NSURL URLWithString: urlString]
                                                   frameURL: frameURL];

        [[IFExtensionsManager sharedNaturalInformExtensionsManager] downloadAndInstallExtension: realURL
                                                                                         window: [[pane controller] window]
                                                                                 notifyDelegate: [pane controller]
                                                                                   javascriptId: item];
    }
}

- (void)finalizeForWebScript {
	pane = nil;
}

@end
