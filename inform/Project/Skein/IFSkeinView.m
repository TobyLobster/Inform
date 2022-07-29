//
//  IFSkeinView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkeinView.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinItemView.h"
#import "IFSkeinLayout.h"
#import "IFSkeinLayoutItem.h"
#import "IFSkeinViewChildren.h"
#import "IFSkeinConstants.h"
#import "IFPreferences.h"
#import "IFUtility.h"

/// Constants
static const CGFloat kSkeinMinEditFieldWidth  = 40.0f;    // Smallest width for editing a command

/// Drawing info
static NSDictionary* itemTextAttributes;

@implementation IFSkeinView {
    IFSkein*        skein;

    // Drag scrolling
    BOOL            dragScrolling;
    NSPoint         dragOrigin;
    NSRect          dragInitialVisible;

    // Cursor
    NSTrackingArea* viewTrackingArea;

    // Editing
    IFSkeinItem*    itemToEdit;
    NSScrollView*   fieldScroller;
    NSTextView*     fieldEditor;
    NSTextStorage*  fieldStorage;
    
    // Context menu item
    IFSkeinItem*    contextItem;

    // Manager for child views
    IFSkeinViewChildren*    skeinViewChildren;
}

@synthesize layoutTree;
@synthesize delegate;
@synthesize selectedItem;

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
	itemTextAttributes = @{ NSFontAttributeName:            [NSFont systemFontOfSize: [IFSkeinView fontSize]],
                            NSForegroundColorAttributeName: [NSColor blackColor] };
    });
}

- (instancetype)initWithFrame: (NSRect)frame {
    self = [super initWithFrame:frame];
	
    if (self) {
        skein               = [[IFSkein alloc] initWithProject: nil];
        viewTrackingArea    = nil;
        selectedItem        = nil;

		layoutTree = [[IFSkeinLayout alloc] init];
		[layoutTree setRootItem: [skein rootItem]];

        // Manager for the child views
        skeinViewChildren = [[IFSkeinViewChildren alloc] initWithSkeinView: self];

        // Use backing layer
        [self setWantsLayer: YES];
    }

    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (BOOL) isFlipped {
	return YES;    // YES puts the origin at the top left corner of the view (NO is bottom left)
}

#pragma mark - Setting/getting the source

@synthesize skein;

- (void) setSkein: (IFSkein*) sk {
	if (skein == sk) return;

	if (skein) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: IFSkeinChangedNotification
													  object: skein];
	}

	skein = sk;
	[layoutTree setRootItem: [sk rootItem]];

	if (skein) {
		// Fixed by Collin Pieper: adding an observer for nil has somewhat unwanted side effects
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinDidChange:)
													 name: IFSkeinChangedNotification
												   object: skein];
	}

    [skein setActiveItem: nil];
    selectedItem = nil;
    itemToEdit = nil;
    contextItem = nil;
    [self layoutSkeinWithAnimation: NO];
}

-(IFSkeinItem*) selectedItem {
    return selectedItem;
}

-(void) setSelectedItem:(IFSkeinItem *)theSelectedItem {
    if( selectedItem != theSelectedItem ) {
        selectedItem = theSelectedItem;

        NSDictionary* userDictionary = @{};
        if( theSelectedItem != nil ) {
            userDictionary = @{ IFSkeinSelectionChangedItemKey: theSelectedItem };
        }
        [[NSNotificationCenter defaultCenter] postNotificationName: IFSkeinSelectionChangedNotification
                                                            object: self
                                                          userInfo: userDictionary ];
    }
}

#pragma mark - Laying things out

- (void) skeinDidChange: (NSNotification*) not {
    if( selectedItem != nil ) {
        if( ![skein.rootItem hasDescendant: selectedItem] ) {
            // If the selected item is no longer in the tree...
            if( [skein.rootItem hasDescendant: skein.activeItem] ) {
                // ...select the active item
                selectedItem = skein.activeItem;
            }
            else {
                // ...select nothing
                [self setSelectedItem: nil];
            }
        }
    }

	[self finishEditing: self];

    NSDictionary * userDictionary = [not userInfo];
    BOOL animate           = [[userDictionary objectForKey: IFSkeinChangedAnimateKey] boolValue];
    BOOL keepActiveVisible = [[userDictionary objectForKey: IFSkeinKeepActiveVisibleKey] boolValue];

    [self layoutSkeinWithAnimation: animate];

    if( keepActiveVisible ) {
        NSRect rect = [skeinViewChildren rectForItem: skein.activeItem];
        if( !NSIsEmptyRect(rect) ) {
            if( !NSContainsRect(self.visibleRect, rect) ) {
                [self scrollRectToVisible: rect];
            }
        }
    }
}

-(void) resizeView {
    NSSize newSize = [layoutTree size];

    // Even if the layout is small, we make sure we fill the superview's frame
    // This ensures we can drag the layout around from anywhere in the panel.
    newSize = NSMakeSize( MAX(newSize.width,  self.superview.frame.size.width),
                          MAX(newSize.height, self.superview.frame.size.height) );

    if( !NSEqualSizes(newSize, self.frame.size) ) {
        [self setFrameSize: newSize];
    }
}

-(NSPoint) currentMousePosition {
    NSPoint currentMousePos = [[self window] mouseLocationOutsideOfEventStream];
    return [self convertPoint: currentMousePos fromView: nil];
}

-(void) updateTrackingAreas {
    [self resizeView];

    // Track the current view rect, so we can change it's mouse cursor
    if( viewTrackingArea ) {
        [self removeTrackingArea:viewTrackingArea];
        viewTrackingArea = nil;
    }

    NSRect visibleRect = [self visibleRect];
    if( !NSIsEmptyRect( visibleRect )) {
        NSTrackingAreaOptions options = NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow;

        // Do we start inside the rectangle?
        if (NSPointInRect([self currentMousePosition], visibleRect)) {
            options |= NSTrackingAssumeInside;
        }

        viewTrackingArea = [[NSTrackingArea alloc] initWithRect: visibleRect
                                                        options: options
                                                          owner: self
                                                       userInfo: nil];
        [self addTrackingArea: viewTrackingArea];
    }

    [super updateTrackingAreas];
}

- (void) layoutSkeinWithAnimation: (BOOL) animate {
    [self finishEditing: self];

    // Re-layout this skein
    [layoutTree setRootItem:     skein.rootItem];
    [layoutTree setActiveItem:   skein.activeItem];
    [layoutTree setSelectedItem: selectedItem];
	[layoutTree layoutSkein];

    // Resize the view to the size of the new layout
    [self resizeView];

    // Tell the report to update itself based on the new skein
    [skeinViewChildren updateReportDetails];

    // Now adjust the layout to take the report into account
    [layoutTree updateLayoutWithReportDetails: skeinViewChildren.reportDetails];

    // Resize the view to the size of the new layout
    [self resizeView];

    // Update views based on new layout, and animate as needed
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration: kSkeinAnimationDuration];

    [skeinViewChildren updateChildrenWithLayout: layoutTree
                                        animate: animate];

    [NSAnimationContext endGrouping];
}

#pragma mark Cursor handling

- (void) cursorUpdate: (NSEvent*) event {
    [[NSCursor openHandCursor] set];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
	return YES;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

-(void) awakeFromNib
{
    if( [IFUtility hasScrollElasticityFeature] ) {
        // Make sure the skein view doesn't have elasticity
        [self.enclosingScrollView setHorizontalScrollElasticity: NSScrollElasticityNone];
        [self.enclosingScrollView setVerticalScrollElasticity:   NSScrollElasticityNone];
    }
}

#pragma mark - Mouse handling

- (void) mouseDown: (NSEvent*) event {
	[self finishEditing: self];

    // We're dragging to move the view around
    [[NSCursor closedHandCursor] set];

    dragScrolling = YES;
    dragOrigin = [event locationInWindow];
    dragInitialVisible = [self visibleRect];
}

- (void) mouseDragged: (NSEvent*) event {
	if (dragScrolling) {
        NSPoint currentPos = [event locationInWindow];
		NSRect newVisRect = dragInitialVisible;
		
		newVisRect.origin.x += dragOrigin.x - currentPos.x;
		newVisRect.origin.y -= dragOrigin.y - currentPos.y;

        // Scroll to the new position
		[self scrollRectToVisible: NSIntegralRect(newVisRect)];

        [[NSCursor closedHandCursor] set];
    }
}

- (void) mouseUp: (NSEvent*) event {
    [[NSCursor openHandCursor] set];
    dragScrolling = NO;
}

#pragma mark - Editing items

- (void)textDidEndEditing:(NSNotification *)aNotification {
	// Check if the user left the field before committing changes and end the edit.
	BOOL success = [[aNotification userInfo][NSTextMovementUserInfoKey] integerValue] != NSTextMovementOther;
	
	if (success)
		[self finishEditing: fieldEditor];				// Store the results
	else
		[self cancelEditing: fieldEditor];				// Abort the edit
}

- (void) finishEditing: (id) sender {
	if (itemToEdit != nil && fieldEditor != nil) {
		IFSkeinItem* parent = [itemToEdit parent];

        // Is there already a child with the same command?
		BOOL siblingAlreadyHasSameCommand = ([parent childWithCommand: [fieldEditor string] isTestSubItem: NO] != itemToEdit);

        if (siblingAlreadyHasSameCommand) {
            // Removing then re-adding the item back into the tree merges the itemToEdit with the existing tree
            [itemToEdit removeFromParent];

            // Set the new command
            [itemToEdit setCommand: [fieldEditor string]];
            
            IFSkeinItem* newItem = [parent addChild: itemToEdit];

            // Update the active/selected item if required
            if (itemToEdit == skein.activeItem) {
                [skein setActiveItem: newItem];
            }
            if (itemToEdit == selectedItem) {
                [self setSelectedItem: newItem];
            }

            itemToEdit = newItem;
        }
        else {
            // Set the new command
            [itemToEdit setCommand: [fieldEditor string]];
        }

        [self cancelEditing: self];
        [skein postSkeinChangedWithAnimate: YES
                         keepActiveVisible: NO];
	}
    else {
		[self cancelEditing: self];
	}
    itemToEdit = nil;
}

- (void) cancelEditing: (id) sender {
	[self setNeedsDisplay: YES];
	[fieldScroller removeFromSuperview];
	
	if (fieldEditor == nil) return;
	
	// Kill off the field editor
	[fieldEditor removeFromSuperview];
	[[self window] makeFirstResponder: self];
	
	fieldEditor = nil;
    itemToEdit = nil;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	[self finishEditing: self];
}

- (void) editItem: (IFSkeinItem*) skeinItem {
	// Finish any existing editing
	[self finishEditing: self];
	[[self window] makeFirstResponder: self];
	
	if ([skeinItem parent] == nil) {
		// Can't edit the root item
		NSBeep();
		return;
	}

    IFSkeinLayoutItem* layoutItem = [skeinViewChildren layoutItemForItem: skeinItem];

	// Allows you to edit an item's command
	IFSkeinLayoutItem* itemD = layoutItem;

	if (itemD == nil) {
		NSLog(@"IFSkeinView: Item not found for editing");
		return;
	}

	// Get the text to edit
	NSString* itemText = [skeinItem command];
	if (itemText == nil) itemText = @"";

	// Area of the text for this item
	NSRect itemFrame = layoutItem.textRect;

	// Make sure the item is wide enough for editing
	if (itemFrame.size.width < kSkeinMinEditFieldWidth) {
		itemFrame.origin.x  -= (kSkeinMinEditFieldWidth - itemFrame.size.width)/2.0;
		itemFrame.size.width = kSkeinMinEditFieldWidth;
	}

	// 'overflow' border
	itemFrame.origin.x      = floor(itemFrame.origin.x - 14.0f);
	itemFrame.origin.y      = floor(itemFrame.origin.y + 4.0f);
	itemFrame.size.width    = floor(itemFrame.size.width + 20.0f);
	itemFrame.size.height   = floor(itemFrame.size.height);

    [self scrollRectToVisible: itemFrame];

	itemToEdit = skeinItem;

	// Construct the scroll view
	if (fieldScroller == nil) {
		fieldScroller = [[NSScrollView alloc] init];
		
		[fieldScroller setHasHorizontalScroller: NO];
		[fieldScroller setHasVerticalScroller: NO];
		[fieldScroller setBorderType: NSGrooveBorder];
	}

	// Construct the field editor
	fieldEditor = (NSTextView*)[[self window] fieldEditor: YES
												forObject: self];

	fieldStorage = [[NSTextStorage alloc] initWithString: itemText
											  attributes: itemTextAttributes];	
	[[fieldEditor textStorage] setAttributedString: fieldStorage];

	[fieldEditor setDelegate: self];
	[fieldScroller setFrame: itemFrame];
	[fieldEditor setFrame: itemFrame];

	[fieldEditor setAlignment: NSTextAlignmentCenter];
	[fieldEditor setFont: itemTextAttributes[NSFontAttributeName]];

	[fieldEditor setRichText:NO];
    if ([fieldEditor respondsToSelector: @selector(setAllowsDocumentBackgroundColorChange:)]) {
        [fieldEditor setAllowsDocumentBackgroundColorChange:NO];
    }
	[fieldEditor setBackgroundColor:[NSColor whiteColor]];

	[[fieldEditor textContainer] setContainerSize: NSMakeSize(itemFrame.size.width - 4.0f, 1e6)];
	[[fieldEditor textContainer] setWidthTracksTextView:NO];
	[[fieldEditor textContainer] setHeightTracksTextView:NO];
	[fieldEditor setHorizontallyResizable:NO];
	[fieldEditor setVerticallyResizable:YES];
	[fieldEditor setDrawsBackground: YES];
	[fieldEditor setEditable: YES];

	// Activate it
	[fieldScroller setDocumentView: fieldEditor];
	[self addSubview: fieldScroller];
	[[self window] makeFirstResponder: fieldEditor];
}


- (void) cancelAnyPerformSelectors {
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
}

#pragma mark - Playing the game

- (void) playToPoint: (IFSkeinItem*) item {
    if( ![self canPlayToHere: item] ) {
        return;
    }
    [self cancelAnyPerformSelectors];

    if (![delegate respondsToSelector: @selector(stopGame)] ||
		![delegate respondsToSelector: @selector(playToPoint:fromPoint:)]) {
		// Can't play to this point: delegate does not support it
		return;
	}

	// Work out if we can play from the active item or not
    if( [skein.activeItem hasDescendant: item] ) {
        // Play from the active item
        [delegate playToPoint: item
                    fromPoint: skein.activeItem];
    }
    else {
        // We need to play from the start
        [delegate stopGame];
        [delegate playToPoint: item
                    fromPoint: skein.rootItem];
    }
}

#pragma mark - Moving around

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
	[self finishEditing: self];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[self finishEditing: self];
}

#pragma mark - Menu support

- (BOOL) canDelete: (IFSkeinItem*) skeinItem {
    IFSkeinItem* itemParent = skeinItem.parent;

    if (itemParent == nil) return NO;
    if( skeinItem.isTestSubItem ) return NO;

    if( [skeinItem hasDescendant: skein.activeItem] ) {
        return NO;
    }

    return YES;
}

-(BOOL) canPlayToHere:(IFSkeinItem*) item {
    return !item.isTestSubItem;
}

-(BOOL) canInsertPreviousItem:(IFSkeinItem*) item {
    if (item.parent == nil) return NO;
    if (item.isTestSubItem) return NO;
    return YES;
}

-(BOOL) canInsertNextItem:(IFSkeinItem*) item {
    if (item.children.count == 0) {
        return YES;
    }
    if (item.children.count == 1) {
        IFSkeinItem* firstChild = item.children[0];
        if( !firstChild.isTestSubItem ) return YES;
    }
    return NO;
}

-(BOOL) canDeleteItem:(IFSkeinItem*) item {
    return [self canDelete: item];
}

-(BOOL) canEditItem:(IFSkeinItem*) item {
    if( item.parent == nil ) return NO;
    if( item.isTestSubItem ) return NO;
    return YES;
}

-(BOOL) canSetWinningItem:(IFSkeinItem*) item {
    if( item.parent == nil ) return NO;
    if( item.isTestSubItem ) return NO;
    return YES;
}

-(BOOL) canSplitThread:(IFSkeinItem*) item {
    if( item.children.count > 0 ) {
        IFSkeinItem* firstChild = item.children[0];
        if( firstChild.isTestSubItem ) {
            return NO;
        }
    }
    return YES;
}

-(BOOL) canDeleteThread:(IFSkeinItem*) item {
    return [self canDelete: item] || (item.parent == nil);
}

-(BOOL) hasMenu:(IFSkeinItem*) item {
    if( !item.isTestSubItem ) return YES;
    if( item.children.count == 0 ) return YES;

    IFSkeinItem* firstChild = item.children[0];
    if( !firstChild.isTestSubItem ) return YES;

    return NO;
}

#pragma mark - Context menu

- (NSMenu *)menuForItem:(IFSkeinItem*) item {
    contextItem = item;

    NSMenu* contextMenu = [[NSMenu alloc] init];
    contextMenu.autoenablesItems = NO;

    // Add menu items for the standard actions
    NSMenuItem* menuItem = nil;
    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Play to Here"]
                                      action: @selector(playToHere:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canPlayToHere:item];

    // -----------------------------------------------
    [contextMenu addItem: [NSMenuItem separatorItem]];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Insert Previous Command"]
                                      action: @selector(insertPreviousItem:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canInsertPreviousItem:item];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Insert Next Command"]
                                      action: @selector(insertNextItem:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canInsertNextItem:item];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Delete Command"]
                                      action: @selector(deleteOneItem:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canDeleteItem:item];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Edit Command"]
                                      action: @selector(editContextItem:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canEditItem:item];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Set Winning Command"]
                                      action: @selector(setWinningCommandItem:)
                               keyEquivalent: @""];
    if ([skein isTheWinningItem: item]) {
        menuItem.state = NSControlStateValueOn;
    } else {
        menuItem.state = NSControlStateValueOff;
    }
    menuItem.enabled = [self canSetWinningItem:item];
    // -----------------------------------------------
    [contextMenu addItem: [NSMenuItem separatorItem]];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Split Thread"]
                                      action: @selector(addNewBranch:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canSplitThread:item];

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Delete Threads from Here"]
                                      action: @selector(deleteItem:)
                               keyEquivalent: @""];
    menuItem.enabled = [self canDeleteThread:item];

    // -----------------------------------------------
    [contextMenu addItem: [NSMenuItem separatorItem]];
    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Bless Command"]
                                      action: @selector(blessItem:)
                               keyEquivalent: @""];
    menuItem.enabled = true;

    menuItem = [contextMenu addItemWithTitle: [IFUtility localizedString: @"Bless all Commands to Here"]
                                      action: @selector(blessToHere:)
                               keyEquivalent: @""];
    menuItem.enabled = true;

    // Return the menu
    return contextMenu;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
	// Find which item that the mouse is over
	NSPoint pointInView = [event locationInWindow];
	pointInView = [self convertPoint: pointInView fromView: nil];
	
	IFSkeinItem* itemAtPoint = [layoutTree itemAtPoint: pointInView];
	
	if (itemAtPoint == nil) return nil;

    return [self menuForItem: itemAtPoint];
}

#pragma mark - Menu actions

- (IBAction) playToHere: (id) sender {
    [self playToPoint: contextItem];
    contextItem = nil;
}

- (IBAction) addNewBranch: (id) sender {
    if( [self canSplitThread: contextItem] ) {
        // Add a new, blank item
        IFSkeinItem* newItem = [contextItem addChild: [[IFSkeinItem alloc] initWithSkein: skein command: @""]];
        
        // Update layout based on the changed skein
        [skein postSkeinChangedWithAnimate: YES
                         keepActiveVisible: NO];

        // Edit the item
        [self editItem: newItem];
    }
    contextItem = nil;
}

- (IBAction) insertPreviousItem: (id) sender {
    if( [self canInsertPreviousItem: contextItem] ) {
        // Get the parent item
        IFSkeinItem* parent = contextItem.parent;
        
        // Remove any child items (these will become children of the new item)
        NSArray* children = [parent.children copy];

        for( IFSkeinItem* child in children ) {
            [child removeFromParent];
        }
        
        // Add a new, blank item
        IFSkeinItem* newItem = [parent addChild: [[IFSkeinItem alloc] initWithSkein: skein command: @""]];

        // Add the child items back in again
        for( IFSkeinItem* child in children ) {
            [newItem addChild: child];
        }

        // Update layout based on the changed skein
        [skein postSkeinChangedWithAnimate: YES
                         keepActiveVisible: NO];

        // Edit the item
        [self editItem: newItem];
    }
    contextItem = nil;
}

- (IBAction) insertNextItem: (id) sender {
    if( [self canInsertNextItem: contextItem] ) {
        if( contextItem.children.count == 1 ) {
            contextItem = contextItem.children[0];
            [self insertPreviousItem: sender];
        }
        else if( contextItem.children.count == 0 ) {
            [self addNewBranch: sender];
        }
    }
    contextItem = nil;
}

- (IBAction) deleteItem: (id) sender {
    if ([self canDeleteThread: contextItem]) {
        BOOL fixSelectedItem = [contextItem hasDescendant: selectedItem];

        if( contextItem.parent == nil ) {
            while( contextItem.children.count > 0 ) {
                [contextItem.children[0] removeFromParent];
            }
            [self setSelectedItem: nil];
        }
        else {
            IFSkeinItem* parent = contextItem.parent;
            [contextItem removeFromParent];

            // Adjust the selected item to remain valid
            if( fixSelectedItem ) {
                if( parent.children.count <= 1) {
                    [self setSelectedItem: parent];
                } else {
                    [self setSelectedItem: nil];
                }
            }
        }

        // Force a layout of the skein
        [skein postSkeinChangedWithAnimate: YES
                         keepActiveVisible: NO];
    }
    contextItem = nil;
}

- (IBAction) deleteOneItem: (id) sender {
    if ([self canDeleteItem: contextItem]) {
        BOOL fixSelectedItem = [contextItem hasDescendant: selectedItem];

        IFSkeinItem* originalParent = contextItem.parent;

        // Work out which is the last dependent item spawned by our potential "test me" command
        IFSkeinItem* dependentLeaf = contextItem;
        while (dependentLeaf.children.count == 1) {
            IFSkeinItem* child = dependentLeaf.children[0];
            if( !child.isTestSubItem ) {
                break;
            }
            dependentLeaf = child;
        }

        // Remember the children of this item
        NSArray* children = [dependentLeaf.children copy];

        // Remove them from the tree
        for( IFSkeinItem* child in children ) {
            [child removeFromParent];
        }

        // Remove this item (and any children)
        [contextItem removeFromParent];

        // Add the children back to the parent item (merging if necessary)
        for( IFSkeinItem* child in children ) {
            [originalParent addChild: child];
        }

        // Adjust the selected item to remain valid
        if( fixSelectedItem ) {
            if( originalParent.children.count <= 1) {
                [self setSelectedItem: originalParent];
            } else {
                [self setSelectedItem: nil];
            }
        }

        // Force a layout of the skein
        [skein postSkeinChangedWithAnimate: YES
                         keepActiveVisible: NO];
    }
    contextItem = nil;
}

- (IBAction) setWinningCommandItem: (id) sender {
    if ([self canSetWinningItem: contextItem]) {
        IFSkeinItem* oldWinningItem = [skein getWinningItem];
        if (oldWinningItem == contextItem) {
            [skein setWinningItem: nil];
            [((NSMenuItem*) sender) setState: NSControlStateValueOff];
        } else {
            [skein setWinningItem: contextItem];
        }

        if (oldWinningItem != nil) {
            // redraw the old item, to remove the winning item star icon
            IFSkeinItemView * oldWinningView = [skeinViewChildren itemViewForItem: oldWinningItem];
            [oldWinningView setNeedsDisplay: YES];
        }

        // Force a layout of the skein, making the new winning item appear
        [skein postSkeinChangedWithAnimate: NO
                         keepActiveVisible: NO];
    }
    contextItem = nil;
}

- (IBAction) editContextItem: (id) sender {
    if( [self canEditItem: contextItem] ) {
        [self editItem: contextItem];
    }
    contextItem = nil;
}

- (IBAction) blessItem: (id) sender {
    contextItem.ideal = [contextItem.actual copy];

    // Force a layout of the skein
    [skein postSkeinChangedWithAnimate: NO
                     keepActiveVisible: NO];
}

- (IBAction) blessToHere: (id) sender {
    while(contextItem != nil ) {
        contextItem.ideal = [contextItem.actual copy];
        contextItem = contextItem.parent;
    }

    // Force a layout of the skein
    [skein postSkeinChangedWithAnimate: NO
                     keepActiveVisible: NO];
}

- (void) saveTranscript: (id) sender {
	if ([self window] == nil) return;
    if( layoutTree.rootLayoutItem.onSelectedLine == NO ) return;

    NSString* string = [self->skein transcriptToPoint: [layoutTree.rootLayoutItem leafSelectedLineItem].item ];

    [IFUtility saveTranscriptPanelWithString: string
                                      window: [self window]];
}

-(IFSkeinItem*) itemAtPoint: (NSPoint) point {
    return [layoutTree itemAtPoint: point];
}

-(void) selectItem: (IFSkeinItem*) item {
    if( selectedItem != item ) {
        [self setSelectedItem: item];
        [self layoutSkeinWithAnimation:YES];
    }
    [self scrollViewToItem: item];
}

- (BOOL) selectItemWithNodeId: (unsigned long) skeinItemNodeId {
    IFSkeinItem* item = [skein.rootItem findItemWithNodeId: skeinItemNodeId];
    if( item ) {
        [self selectItem: item];
        return YES;
    }
    return NO;
}

-(void) scrollViewToItem: (IFSkeinItem*) scrollToItem {
    if( scrollToItem == nil ) return;

    NSRect rect = [skeinViewChildren rectForItem: skein.activeItem];
    if( !NSIsEmptyRect(rect) ) {
        // Animate the controlView
        NSRect startingRect = [self frame];
        NSRect endingRect = startingRect;
        endingRect.origin = rect.origin;

        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"frame"];
        anim.fromValue = @(startingRect);
        anim.toValue = @(endingRect);
        anim.delegate = self;
        self.animations = @{@"frame": anim};

        self.animator.frame = endingRect;
    }
}

-(void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless {
    if( bless ) {
        item.ideal = [item.actual copy];
    } else {
        item.ideal = @"";
    }

    // Force a layout of the skein
    [skein postSkeinChangedWithAnimate: NO
                     keepActiveVisible: NO];
}

+ (CGFloat) fontSize {
    return kSkeinDefaultItemFontSize * [[IFPreferences sharedPreferences] appFontSizeMultiplier];
}

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    // Adjust edit field text size
    itemTextAttributes = [IFUtility adjustAttributesFontSize: itemTextAttributes size: [[self class] fontSize]];

    // Adjust child views
    [skeinViewChildren fontSizePreferenceChanged];

    // Mark skein as needing to recalculate command sizes
    [skein.rootItem forceCommandSizeChangeRecursively];

    // Update layout
    [skein postSkeinChangedWithAnimate: NO
                     keepActiveVisible: NO];
}

typedef BOOL(^checkFunc)(IFSkeinLayoutItem* item);

- (BOOL) recursiveCheckItems: (checkFunc) checkFunction {
    if( layoutTree.rootLayoutItem == nil ) {
        return NO;
    }
    NSMutableArray* queue = [[NSMutableArray alloc] init];

    [queue addObject:layoutTree.rootLayoutItem];
    while ( [queue count] > 0 ) {
        IFSkeinLayoutItem* layoutItem = [queue lastObject];
        [queue removeLastObject];

        if( checkFunction(layoutItem) ) {
            return YES;
        }
        [queue addObjectsFromArray:layoutItem.children];
    }
    return NO;
}

- (BOOL) isAnyItemPurple {
    return [self recursiveCheckItems: ^(IFSkeinLayoutItem* layoutItem) {
                return (BOOL) ( layoutItem.recentlyPlayed );
            }];
}

- (BOOL) isAnyItemGrey {
    return [self recursiveCheckItems: ^(IFSkeinLayoutItem* layoutItem) {
        return (BOOL) (( !layoutItem.recentlyPlayed ) && ( !layoutItem.onSelectedLine ));
    }];
}

- (BOOL) isAnyItemBlue {
    return [self recursiveCheckItems: ^(IFSkeinLayoutItem* layoutItem) {
        return (BOOL) (( !layoutItem.recentlyPlayed ) && ( layoutItem.onSelectedLine ));
    }];
}

- (BOOL) isReportVisible {
    return layoutTree.selectedItem != nil;
}

- (BOOL) isTickVisible {
    if( layoutTree.selectedLayoutItem != nil ) {
        // Go to leaf of selected line
        IFSkeinLayoutItem* layoutItem = layoutTree.selectedLayoutItem;
        while (layoutItem.selectedLineChild != nil ) {
            layoutItem = layoutItem.selectedLineChild;
        }

        // Has anything on the selected line got differences?
        while ( layoutItem != nil ) {
            if( layoutItem.item.hasDifferences ) {
                return YES;
            }
            layoutItem = layoutItem.parent;
        }
    }
    return NO;
}

- (BOOL) isCrossVisible {
    if( layoutTree.selectedLayoutItem != nil ) {
        // Go to leaf of selected line
        IFSkeinLayoutItem* layoutItem = layoutTree.selectedLayoutItem;
        while (layoutItem.selectedLineChild != nil ) {
            layoutItem = layoutItem.selectedLineChild;
        }

        // Has anything on the selected line got differences?
        while ( layoutItem != nil ) {
            if( !layoutItem.item.hasDifferences ) {
                return YES;
            }
            layoutItem = layoutItem.parent;
        }
    }
    return NO;
}

- (BOOL) isBadgedItemVisible {
    return [self recursiveCheckItems: ^(IFSkeinLayoutItem* layoutItem) {
        return layoutItem.item.hasBadge;
    }];
}

- (NSInteger) itemsVisible {
    NSInteger __block count = 0;
    [self recursiveCheckItems: ^(IFSkeinLayoutItem* layoutItem) {
        count++;
        return NO;
    }];

    return count;
}

@end
