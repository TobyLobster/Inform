//
//  IFFindWebView.m
//  Inform
//
//  Created by Andrew Hunter on 23/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFFindWebView.h"


@implementation WKWebView(IFFindWebView)

#pragma mark - Basic interface

# pragma mark - Find

- (void) findNextMatch: (NSString*) match
                ofType: (IFFindType) type
     completionHandler: (void (^)(bool result))completionHandler {
    BOOL insensitive = (type&IFFindCaseInsensitive)!=0;

    if (@available(macOS 11.0, *)) {
        WKFindConfiguration *configuration = [[WKFindConfiguration alloc] init];
        configuration.backwards = false;
        configuration.caseSensitive = !insensitive;
        configuration.wraps = true;

        [self      findString: match
             withConfiguration: configuration
             completionHandler: ^(WKFindResult *result) {
            if (completionHandler != nil) {
                completionHandler(result.matchFound);
            }
        }];
    } else {
        // Fallback on earlier versions
        if (completionHandler != nil) {
            completionHandler(false);
        }
    }
}

- (void) findPreviousMatch: (NSString*) match
                    ofType: (IFFindType) type
         completionHandler: (void (^)(bool result))completionHandler {
    BOOL insensitive = (type&IFFindCaseInsensitive)!=0;

    if (@available(macOS 11.0, *)) {
        WKFindConfiguration *configuration = [[WKFindConfiguration alloc] init];
        configuration.backwards = true;
        configuration.caseSensitive = !insensitive;
        configuration.wraps = true;

        [self      findString: match
             withConfiguration: configuration
             completionHandler: ^(WKFindResult *result) {
            if (completionHandler != nil) {
                completionHandler(result.matchFound);
            }
        }];
    } else {
        // Fallback on earlier versions
        if (completionHandler != nil) {
            completionHandler(false);
        }
    }
}

- (BOOL) canUseFindType: (IFFindType) find {
    switch (find) {
        case IFFindContains:
            return YES;

        case IFFindBeginsWith:
        case IFFindCompleteWord:
        case IFFindRegexp:
        default:
            return NO;
    }
}

- (void) currentSelectionForFindWithCompletionHandler:(void (^)(NSString*))completionHandler {
    NSString *script = @"window.getSelection().toString()";
    [self evaluateJavaScript:script
           completionHandler:^(NSString *selectedString, NSError *error) {
        if (completionHandler != nil) {
            if (error == nil) {
                completionHandler(selectedString);
            } else {
                NSBeep();
                completionHandler(nil);
            }
        }
    }];
}

@end
