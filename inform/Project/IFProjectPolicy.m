//
//  IFProjectPolicy.m
//  Inform
//
//  Created by Andrew Hunter on 04/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "IFProjectPolicy.h"
#import "IFProjectPane.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"

@implementation IFProjectPolicy

// = Annoying bug workaround =
+ (NSURL*) fileURLWithPath: (NSString*) file {
	NSMutableString* url;
	unsigned char chr;
	int x;
	
	if (![file isAbsolutePath]) {
		return nil;
	}
	
	url = [[NSMutableString alloc] initWithString: @"file://"];
	const unsigned char* utf8 = (unsigned char*)[file UTF8String];
	
	// Create a URL string
	for (x=0; utf8[x] != 0; x++) {
		chr = utf8[x];
		
		switch (chr) {
			case ';':
			case ':':
			case ' ':
			case '?':
			case '%':
			case '@':
			case '=':
			case '$':
			case '+':
			case ',':
			case '&':
				[url appendFormat: @"%%%02X", (unsigned int)chr];
				break;
				
			default:
				if (isalnum(chr) || chr == '/' || chr == '.') {
					unichar theChar = chr;
					[url appendString: [NSString stringWithCharacters:&theChar length:1]];
					break;
				} else {
					[url appendFormat: @"%%%02X", (unsigned int)chr];
				}
		}
	}
	
	NSURL* res = [NSURL URLWithString: url];
	
	if (res == nil) {
		res = [NSURL fileURLWithPath: file];
	}
	
	[url release];
	
	return res;
}

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super init];
	
	if (self) {
		projectController = controller; // NOT retained; avoids loops
		redirectToDocs = NO;
		redirectToExtensionDocs = NO;
	}
	
	return self;
}

// = Setting up =

- (void) setProjectController: (IFProjectController*) controller {
	projectController = controller;
}

- (IFProjectController*) projectController {
	return projectController;
}

- (void) setRedirectToDocs: (BOOL) redirect {
	redirectToDocs = redirect;
}

- (BOOL) redirectToDocs {
	return redirectToDocs;
}

- (void) setRedirectToExtensionDocs: (BOOL) redirect {
	redirectToExtensionDocs = redirect;
}

- (BOOL) redirectToExtensionDocs {
	return redirectToExtensionDocs;
}

+(NSURL*) urlFromLibraryURL: (NSURL*) url
                   frameURL: (NSURL*) frameURL {
    // Replace the "library:" prefix of the URL string with the URL for the enclosing document
    // frame URL looks like: "inform:/fake/index.html"
    // Our URL looks like "library:/payloads/Emily%20Short/Transit%20System.i7x"
    // We transform this into "inform:/fake/payloads/Emily%20Short/Transit%20System.i7x"

    if (( frameURL.path != nil ) && ( url.path != nil )) {
        // Remove last object from path, and add in the other path
        NSArray* framePathComponents = [frameURL.path componentsSeparatedByString:@"/"];
        NSArray* urlPathComponents   = [url.path componentsSeparatedByString:@"/"];

        NSMutableArray* newPath = [[NSMutableArray alloc] initWithArray: framePathComponents ];
        if( [newPath count] > 0 ) {
            [newPath removeObjectAtIndex:0];    // remove first '/' component
        }
        if( [newPath count] > 0 ) {
            [newPath removeLastObject];         // remove final path comonent "index.html"
        }
        
        NSMutableArray* urlPath = [[NSMutableArray alloc] initWithArray: urlPathComponents ];
        if( [urlPath count] > 0 ) {
            [urlPath removeObjectAtIndex:0];    // remove first '/' component
        }
        
        [newPath addObjectsFromArray: urlPath];
        [urlPath release];

        // Escape encode the paths, as they were (unhelpfully) unescaped with the .path method
        for(int index = 0; index < [newPath count]; index++) {
            NSString* escapedString = [[newPath objectAtIndex: index] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
            [newPath replaceObjectAtIndex: index
                               withObject: escapedString];
        }

        // Create the new URL string
        NSMutableString* newUrlString = [[NSMutableString alloc] initWithFormat: @"%@:/", frameURL.scheme];
        if( frameURL.host != nil ) {
            [newUrlString appendString: @"/"];
            [newUrlString appendString: frameURL.host];
            [newUrlString appendString: @"/"];
        }
        [newUrlString appendString: [newPath componentsJoinedByString:@"/"]];
        
        [newPath release];
        
        NSURL* newURL = [[[NSURL alloc] initWithString: newUrlString] autorelease];
        
        [newUrlString release];
        
        return newURL;
    }
    return nil;
}

- (NSDictionary *)explodeString:(NSString*) string innerGlue:(NSString *)innerGlue outerGlue:(NSString *)outerGlue {
    // Explode based on outter glue
    NSArray *firstExplode = [string componentsSeparatedByString:outerGlue];
    NSArray *secondExplode;

    // Explode based on inner glue
    NSInteger count = [firstExplode count];
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
    	secondExplode = [(NSString *)[firstExplode objectAtIndex:i] componentsSeparatedByString:innerGlue];
    	if ([secondExplode count] == 2) {
    		[returnDictionary setObject:[secondExplode objectAtIndex:1] forKey:[secondExplode objectAtIndex:0]];
    	}
    }
    return returnDictionary;
}

// = Our life as a policy delegate =

- (void)					webView: (WebView *)sender
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation
							request: (NSURLRequest *)request
							  frame: (WebFrame *)frame
				   decisionListener: (id<WebPolicyDecisionListener>)listener {
	// Blah. Link failure if WebKit isn't available here. Constants aren't weak linked
	
	// Double blah. WebNavigationTypeLinkClicked == null, but the action value == 0. Bleh
	if ([[actionInformation objectForKey: WebActionNavigationTypeKey] intValue] == 0) {
		NSURL* url = [request URL];
		
		// Source file redirects
		if ([[url scheme] isEqualTo: @"source"]) {
			// We deal with these ourselves
			[listener ignore];
			
			// Format is 'source file name#line number'
			NSString* path = [[[request URL] resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
			NSArray* components = [path componentsSeparatedByString: @"#"];
			
			if ([components count] != 2) {
				NSLog(@"Bad source URL: %@", path);
				if ([components count] < 2) return;
				// (try anyway)
			}
			
			NSString* sourceFile = [[components objectAtIndex: 0] stringByReplacingPercentEscapesUsingEncoding: NSUnicodeStringEncoding];
			NSString* sourceLine = [[components objectAtIndex: 1] stringByReplacingPercentEscapesUsingEncoding: NSUnicodeStringEncoding];
			
			// sourceLine can have format 'line10' or '10'. 'line10' is more likely
			int lineNumber = [sourceLine intValue];
			
			if (lineNumber == 0 && [[sourceLine substringToIndex: 4] isEqualToString: @"line"]) {
				lineNumber = [[sourceLine substringFromIndex: 4] intValue];
			}
			
			// Move to the appropriate place in the file
			if (![projectController selectSourceFile: sourceFile]) {
				NSLog(@"Can't select source file '%@'", sourceFile);
				return;
			}			
			
			if (lineNumber >= 0) [projectController moveToSourceFileLine: lineNumber];
			[projectController removeHighlightsOfStyle: IFLineStyleHighlight];
			[projectController highlightSourceFileLine: lineNumber
												inFile: sourceFile
												 style: IFLineStyleHighlight];
			
			// Finished
			return;
		}
        else if ([[url scheme] isEqualTo: @"library"]) {
            IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
            if( mgr ) {
                NSURL* frameURL = [[[frame dataSource] request] URL];
                NSURL* newURL = [[self class] urlFromLibraryURL: url
                                                       frameURL: frameURL];

                if ( newURL != nil ) {
                    // Query at the end of the URL may have id=<number> on the end
                    NSDictionary *queryDict = [self explodeString: url.query
                                                        innerGlue: @"="
                                                        outerGlue: @"&"];
                    NSString* javascriptId = [queryDict objectForKey:@"id"];

                    // Remove last object from path, and add in the other path
                    [mgr downloadAndInstallExtension: newURL
                                              window: [sender window]
                                      notifyDelegate: projectController
                                        javascriptId: javascriptId];
                }
                else {
                    NSLog(@"URL '%@' could not be transformed using frameURL '%@'", url, frameURL);
                }
            }
            return;
        }

        // Open extenal links in separate default browser app
		if (([[url scheme] isEqualTo: @"http"]) || ([[url scheme] isEqualTo: @"https"])) {
            [listener ignore];
            [[NSWorkspace sharedWorkspace] openURL:[request URL]];
            return;
        }

		// General redirects
		if((redirectToDocs) || (redirectToExtensionDocs)) {
			WebDataSource* activeSource = [frame dataSource];
			
			if (activeSource == nil) {
				activeSource = [frame provisionalDataSource];
				if (activeSource != nil) {
					NSLog(@"Using the provisional data source - frame not finished loading?");
				}
			}
			
			if (activeSource == nil) {
				NSLog(@"Unable to establish a datasource for this frame: will probably redirect anyway");
			}
			
			if ([activeSource request] == nil) {
				NSLog(@"Source found, but unable to retrieve the request");
			} else if ([[activeSource request] URL] == nil) {
				NSLog(@"Source found, but unable to retrieve the URL from the request");
			}

			NSURL* absolute1 = [[[request URL] absoluteURL] standardizedURL];
			NSURL* absolute2 = [[[[activeSource request] URL] absoluteURL] standardizedURL];

			BOOL willRedirect = YES;

			// Don't redirect if the page is part of the project
			if ([absolute1 isFileURL] && [absolute2 isFileURL]) {
				NSString* path1 = [[[absolute1 path] stringByStandardizingPath] lowercaseString];
				NSString* projectPath = [[[[projectController document] fileName] stringByStandardizingPath] lowercaseString];
				
				if ([path1 rangeOfString: projectPath].location == 0)
					willRedirect = NO;
			}

			// We only redirect if the page is different to the current one
			if ([IFUtility url:absolute1 equals:absolute2]) {
				willRedirect = NO;
			}
			
			if (willRedirect) {
				[listener ignore];
                if( redirectToDocs )
                {
                    [[[projectController auxPane] documentationPage] openURL: [[[request URL] copy] autorelease]];
                } else if (redirectToExtensionDocs)
                {
                    [[[projectController auxPane] extensionsPage] openURL: [[[request URL] copy] autorelease]];
                }
                
				return;
			}
		}
	}
	
	// default action
	[listener use];
}

@end
