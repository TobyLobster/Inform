//
//  IFProjectPolicy.m
//  Inform
//
//  Created by Andrew Hunter on 04/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "IFProjectPolicy.h"
#import "IFProjectController.h"
#import "IFProjectPane.h"
#import "IFProjectTypes.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFDocumentationPage.h"
#import "IFExtensionsPage.h"
#import "IFProject.h"

@implementation IFProjectPolicy {
    IFProjectController* projectController;
    BOOL redirectToDocs;
    BOOL redirectToExtensionDocs;
}


#pragma mark - Initialisation
- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super init];

	if (self) {
		projectController = controller;
		redirectToDocs = NO;
		redirectToExtensionDocs = NO;
	}

	return self;
}

#pragma mark - Setting up

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

        // Escape encode the paths, as they were (unhelpfully) unescaped with the .path method
        for(NSInteger index = 0; index < [newPath count]; index++) {
            NSString* escapedString = [newPath[index] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
            newPath[index] = escapedString;
        }

        // Create the new URL string
        NSMutableString* newUrlString = [[NSMutableString alloc] initWithFormat: @"%@:/", frameURL.scheme];
        if( frameURL.host != nil ) {
            [newUrlString appendString: @"/"];
            [newUrlString appendString: frameURL.host];
            [newUrlString appendString: @"/"];
        }
        [newUrlString appendString: [newPath componentsJoinedByString:@"/"]];

        NSURL* newURL = [[NSURL alloc] initWithString: newUrlString];
        return newURL;
    }
    return nil;
}

- (NSDictionary *)explodeString:(NSString*) string innerGlue:(NSString *)innerGlue outerGlue:(NSString *)outerGlue {
    // Explode based on outer glue
    NSArray *firstExplode = [string componentsSeparatedByString:outerGlue];
    NSArray *secondExplode;

    // Explode based on inner glue
    NSInteger count = [firstExplode count];
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
    	secondExplode = [(NSString *)firstExplode[i] componentsSeparatedByString:innerGlue];
    	if ([secondExplode count] == 2) {
    		returnDictionary[secondExplode[0]] = secondExplode[1];
    	}
    }
    return returnDictionary;
}

#pragma mark - Our life as a policy delegate

- (void)					webView: (WebView *)sender
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation
							request: (NSURLRequest *)request
							  frame: (WebFrame *)frame
				   decisionListener: (id<WebPolicyDecisionListener>)listener {
	if ([actionInformation[WebActionNavigationTypeKey] intValue] == WebNavigationTypeLinkClicked) {
		NSURL* url = [request URL];
		
		// Source file redirects
		if ([[url scheme] isEqualTo: @"source"]) {
			// We deal with these ourselves
			[listener ignore];
			
			// Format is 'source file name#line number'
            NSArray* results = [IFUtility decodeSourceSchemeURL: [request URL]];
            results = [[projectController document] redirectLinksToExtensionSourceCode: results];
            if( results == nil ) {
                return;
            }
            NSString* sourceFile = results[0];
            int lineNumber = [results[1] intValue];

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
        else if ([[url scheme] isEqualTo: @"skein"]) {
            // We deal with these ourselves
            [listener ignore];

            // e.g. 'skein:1003?case=B'
            NSArray* results = [IFUtility decodeSkeinSchemeURL: [request URL]];
            if( results ) {
                NSString* testCase = results[0];
                NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
                unsigned long skeinNodeId = [[formatter numberFromString:results[1]] unsignedLongValue];

                // Move to the appropriate place in the file
                if (![projectController showTestCase: testCase skeinNode: skeinNodeId]) {
                    NSLog(@"Can't select test case '%@'", testCase);
                    return;
                }
            }

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
                    NSString* javascriptId = queryDict[@"id"];

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
				NSString* path1         = [absolute1.path lowercaseString];
				NSString* projectPath   = [[[projectController document] fileURL].path lowercaseString];

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
                    [[[projectController auxPane] documentationPage] openURL: [[request URL] copy]];
                } else if (redirectToExtensionDocs)
                {
                    [[[projectController auxPane] extensionsPage] openURL: [[request URL] copy]];
                }
                
				return;
			}
		}
	}
	
	// default action
	[listener use];
}

@end
