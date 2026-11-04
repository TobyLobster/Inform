//
//  IFWebViewHelper.h
//  Inform
//
//  Created by Toby Nelson on 04/05/2023.
//

#ifndef IFWebViewHelper_h
#define IFWebViewHelper_h

#import <Cocoa/Cocoa.h>
#import "IFProjectPane.h"

@class IFProjectController;
@class IFProject;

///
/// Class designed to provide helper functions for creating and maintaining web views.
///
@interface IFWebViewHelper : NSObject<WKUIDelegate, WKURLSchemeHandler, WKScriptMessageHandler>

// Initialisation
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithProjectController: (IFProjectController*) theProjectController
                                  withPane: (IFProjectPane*) newPane NS_DESIGNATED_INITIALIZER;

#pragma mark - JavaScript operations

- (WKWebView *) createWebViewWithFrame:(CGRect) frame;
/// Selects a specific view (valid names are source, documentation, skein, etc)
- (void) selectView: (NSString*) view;
/// Pastes some code into the source view at the current insertion point
- (void) pasteCode: (NSString*) code;
/// Creates a new project with some code in the source view
- (void) createNewProject: (NSString*) title
                    story: (NSString*) code;
- (void) openUrl: (NSString*) url;

#pragma mark - Preferences changed

- (void) fontSizePreferenceChanged: (WKWebView*) wView;

@end

#endif /* IFWebViewHelper_h */
