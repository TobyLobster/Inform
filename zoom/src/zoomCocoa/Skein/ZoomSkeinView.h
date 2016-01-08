//
//  ZoomSkeinView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomSkein.h"
#import "ZoomSkeinItem.h"
#import "ZoomSkeinLayout.h"

extern NSString* ZoomSkeinItemPboardType;

@interface ZoomSkeinView : NSView<NSTextViewDelegate> {
	ZoomSkein* skein;
	
	BOOL skeinNeedsLayout;
	
	// Layout
	ZoomSkeinLayout* layout;
	
	// Cursor flags
	BOOL overWindow;
	BOOL overItem;
	
	NSMutableArray* trackingRects;
	NSMutableArray* trackingItems;
	ZoomSkeinItem* trackedItem;
	ZoomSkeinItem* clickedItem;
	
	// Dragging items
	BOOL    dragCanMove;

	// Drag scrolling
	BOOL    dragScrolling;
	NSPoint dragOrigin;
	NSRect  dragInitialVisible;
	
	// Clicking buttons
	int activeButton;
	int lastButton;
	
	// Annoyingly poor support for tracking rects band-aid
	NSRect lastVisibleRect;
	
	// Editing things
	ZoomSkeinItem* itemToEdit;
	ZoomSkeinItem* mostRecentItem;
	NSScrollView* fieldScroller;
	NSTextView* fieldEditor;
	NSTextStorage* fieldStorage;
	
	BOOL editingAnnotation;
	
	float itemWidth;
	float itemHeight;
	
	// The delegate
	NSObject* delegate;
	
	// Context menu
	ZoomSkeinItem* contextItem;
}

// Setting/getting the source
@property (atomic, strong) ZoomSkein *skein;

// Laying things out
- (void) skeinNeedsLayout;

- (void) setItemWidth: (float) itemWidth;
- (void) setItemHeight: (float) itemHeight;

// The delegate
@property (atomic, assign) id delegate;

// Affecting the display
- (void) scrollToItem: (ZoomSkeinItem*) item;

- (void) editItem: (ZoomSkeinItem*) skeinItem;
- (void) editItemAnnotation: (ZoomSkeinItem*) skeinItem;
@property (atomic, strong) ZoomSkeinItem *selectedItem;

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

- (void) layoutSkein;

@end

// = Using with the web kit =
#import <WebKit/WebKit.h>

@interface ZoomSkeinView(ZoomSkeinViewWeb)<WebDocumentView>

@end

// = Delegate =
@interface NSObject(ZoomSkeinViewDelegate)

// Playing the game
- (void) restartGame;
- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) currentPoint;

// The transcript
- (void) transcriptToPoint: (ZoomSkeinItem*) point;

// Various types of possible error
- (void) cantDeleteActiveBranch;										// User attempted to delete an item on the active skein branch (which can't be done)
- (void) cantEditRootItem;												// User attemptted to edit the root skein item

@end
