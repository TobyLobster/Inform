//
//  IFHeaderController.m
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHeaderController.h"
#import "IFUtility.h"
#import "IFSyntaxTypes.h"
#import "IFIntelSymbol.h"

@implementation IFHeaderController {
    /// The root of the headers being managed by this object
    IFHeader* rootHeader;
    /// The header that the user has most recently selected
    IFHeader* selectedHeader;
    /// The most recent intel file object
    IFIntelFile* intelFile;

    /// The header views being managed by this controller
    NSMutableArray<NSView<IFHeaderView>*>* headerViews;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		headerViews = [[NSMutableArray alloc] init];
	}
	
	return self;
}

#pragma mark - Sending messages to the views

- (void) refreshHeaders {
	// Send the refreshHeaders message to all of the views that support it
	for( NSObject<IFHeaderView>* headerView in headerViews ) {
		if ([headerView respondsToSelector: @selector(refreshHeaders:)]) {
			[headerView refreshHeaders: self];
		}
	}
}

- (void) setSelectedHeader: (IFHeader*) newSelectedHeader {
	// Update the currently selected header
	selectedHeader = newSelectedHeader;
	
	// Send the setSelectedHeader message to all of the views that support it
	for( NSObject<IFHeaderView>* headerView in headerViews ) {
		if ([headerView respondsToSelector: @selector(refreshHeaders:)]) {
			[headerView setSelectedHeader: newSelectedHeader
							   controller: self];
		}
	}
}

#pragma mark - Managing the collection of headings being maintained by this object

- (void) setChildrenForHeader: (IFHeader*) root
					   symbol: (IFIntelSymbol*) symbol 
					  recurse: (BOOL) recurse {
	IFIntelSymbol* child = symbol.child;
	
	// If the symbol has no children then don't add it to the list
	if (!child) {
		root.children = @[];
		return;
	}
	
	// Otherwise, build up the set of symbols from the children of this item
	NSMutableArray* newChildren = [[NSMutableArray alloc] init];
	while (child) {
		// Build the new header
		IFHeader* newChild = [[IFHeader alloc] initWithName: child.name
													 parent: root
												   children: nil];
		newChild.symbol = child;
		
		// Add it to the array
		[newChildren addObject: newChild];
		
		// Recurse if necessary
		if (recurse) {
			[self setChildrenForHeader: newChild
								symbol: child
							   recurse: YES];
		}
		
		// Done with this item

		// Move onto the sibling for this header
		child = child.sibling;
	}
	
	// Set the children for this symbol
	root.children = newChildren;
}

- (void) updateFromIntelligence: (IFIntelFile*) intel {
	// Change the intel file object
	intelFile = intel;
    if (intel.firstSymbol == NULL) {
        return;
    }
	
	// Firstly, build up a header structure from the intelligence object

    // "Story"
	IFHeader* storyRoot = [[IFHeader alloc] initWithName: intel.firstSymbol.name
                                                  parent: nil
                                                children: nil];
	[self setChildrenForHeader: storyRoot
						symbol: intel.firstSymbol
					   recurse: YES];

    // "---- DOCUMENTATION ----"
    IFIntelSymbol* documentationRootSymbol = intel.firstSymbol;
    while( documentationRootSymbol != nil ) {
        documentationRootSymbol = documentationRootSymbol.nextSymbol;
        if( documentationRootSymbol.level == 0 ) {
            break;
        }
    }

    IFHeader* newRoot = nil;
    if( documentationRootSymbol != nil ) {
        storyRoot.headingName = [IFUtility localizedString: @"HeaderExtensionTitle"];

        // Create documentation header
        IFHeader* docRoot = [[IFHeader alloc] initWithName: [IFUtility localizedString: @"HeaderDocumentationTitle"]
                                                    parent: nil
                                                  children: nil];
        docRoot.symbol = documentationRootSymbol;
        [self setChildrenForHeader: docRoot
                            symbol: documentationRootSymbol
                           recurse: YES];

        newRoot = [[IFHeader alloc] initWithName: [IFUtility localizedString: @"HeaderPage"]
                                          parent: nil
                                        children: @[storyRoot, docRoot]];
    }
    else {
        newRoot = [[IFHeader alloc] initWithName: [IFUtility localizedString: @"HeaderPage"]
                                          parent: nil
                                        children: @[storyRoot]];
    }

	rootHeader = newRoot;
	
	// Cause a general update of the header list
	[self refreshHeaders];
}

@synthesize rootHeader;
@synthesize selectedHeader;
@synthesize intelFile;

#pragma mark - Managing the views being controlled

- (void) addHeaderView: (NSView<IFHeaderView>*) newHeaderView {
	if (!newHeaderView) {
		return;
	}
	
	if ([headerViews indexOfObjectIdenticalTo: newHeaderView] != NSNotFound) {
		// Do nothing if this view has already been added to this controller
		return;
	}
	
	// Add the object to the controller
	[headerViews addObject: newHeaderView];
	
	// Notify that it should update its list of headers from this controller
	if ([newHeaderView respondsToSelector: @selector(refreshHeaders:)]) {
		[newHeaderView refreshHeaders: self];
	}
}

- (void) removeHeaderView: (NSView<IFHeaderView>*) oldHeaderView {
	// Ensure that we don't accidentally self destruct a header view that's in use
	//[[oldHeaderView retain] autorelease];
	
	// Remove the old header view from the list of headers
	[headerViews removeObjectIdenticalTo: oldHeaderView];
}

@end
