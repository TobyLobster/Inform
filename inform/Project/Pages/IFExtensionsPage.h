//
//  IFExtensionsPage.h
//  Inform-xc2
//
//  Created by Toby Nelson on 09/02/2014.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"

#import "IFPageBarCell.h"

//
// The 'extensions' page
//
@interface IFExtensionsPage : IFPage {
	// The documentation view
	WebView* wView;										// The web view that displays the documentation
	
	// Page cells
	IFPageBarCell* homeCell;                            // The 'Home' cell
	IFPageBarCell* definitionsCell;						// The 'Definitions' cell
	IFPageBarCell* publicLibraryCell;					// The 'Public Library' cell
    NSDictionary* tabDictionary;                        // Maps URL paths to cells
    
    bool reloadingBecauseCensusCompleted;
    BOOL loadingFailureWebPage;
}

// The documentation view
- (void) openURL: (NSURL*) url;							// Tells the view to open a specific URL
- (IBAction) showHome: (id) sender;						// Opens the home page
- (void) extensionUpdated:(NSString*) javascriptId;

- (id) initWithProjectController: (IFProjectController*) controller;

@end
