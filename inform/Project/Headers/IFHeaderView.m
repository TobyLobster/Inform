//
//  IFHeaderView.m
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFHeaderView.h"
#import "IFUtility.h"
#import "IFPreferences.h"
#import "IFColourTheme.h"
#import "IFHeaderController.h"

@implementation IFHeaderView {
    /// The display depth for this view
    int displayDepth;
    /// The root header that this view should display
    IFHeader* rootHeader;
    /// The root header node
    IFHeaderNode* rootHeaderNode;
    /// The header node that we're editing at the moment
    IFHeaderNode* editNode;
    NSColor* backgroundColour;

    /// The text view that's performing editing at the moment
    NSTextView* editor;
    /// Text storage for the field editor
    NSTextStorage* editStorage;
}

#pragma mark - Initialisation

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        displayDepth = 5;
        backgroundColour = [[NSColor whiteColor] copy];
    }
    return self;
}

#pragma mark - Information about this view

@synthesize rootHeaderNode;

#pragma mark - Updating the view

- (void) sizeView {
    // Resize the view
    NSRect rootFrame = [rootHeaderNode frame];
    rootFrame.size.width = [self frame].size.width;
    rootFrame.size.height += 5;

    if (message && [self enclosingScrollView]) {
        rootFrame.size = [[self enclosingScrollView] contentSize];
        [self setAutoresizingMask: [self autoresizingMask] | NSViewHeightSizable];
    } else {
        [self setAutoresizingMask: [self autoresizingMask] & ~NSViewHeightSizable];
    }

    [self setFrameSize: rootFrame.size];
}

- (void) updateFromRoot {
    // Replace the root header node
    rootHeaderNode = [[IFHeaderNode alloc] initWithHeader: rootHeader
                                                 position: NSMakePoint(0,0)
                                                    depth: 0];
    int populateToDepth = displayDepth;
    // HACK: If on level 5, include level 6 (examples)
    if( populateToDepth == 5 ) populateToDepth++;

    [rootHeaderNode populateToDepth: populateToDepth];

    // Add a message if necessary
    if ([[rootHeaderNode children] count] == 0) {
        if ([[rootHeader children] count] == 0) {
            [self setMessage: [IFUtility localizedString: @"NoHeadingsSet"
                                                 default: @""]];
        } else {
            [self setMessage: [IFUtility localizedString: @"NoHeadingsVisible"
                                                 default: @""]];
        }
    } else {
        message = nil;
    }

    // Redraw the display
    [self sizeView];
    [self setNeedsDisplay: YES];
}

@synthesize message;
- (void) setMessage: (NSString*) newMessage {
    if ([newMessage length] == 0) newMessage = nil;
    message = [newMessage copy];

    [self sizeView];
    [self setNeedsDisplay: YES];
}

#pragma mark - Settings for this view

- (BOOL) isFlipped {
    return YES;
}

@synthesize displayDepth;

- (void) setDisplayDepth: (int) newDisplayDepth {
    // Set the display depth for this view
    displayDepth = newDisplayDepth;

    // Refresh the view
    [self updateFromRoot];
}


-(BOOL) acceptsFirstResponder {
    return YES;
}

@synthesize delegate;
@synthesize backgroundColour;

#pragma mark - Drawing

- (void)drawRect:(NSRect)rect {
    // Draw the background
    [backgroundColour set];
    NSRectFill(rect);

    // Draw the message, if any
    if (message) {
        // Get the style for the message
        NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setAlignment: NSTextAlignmentCenter];

        // Find text colour
        NSColor* textColour = [NSColor textColor];

        IFColourTheme* theme = [[IFPreferences sharedPreferences] getCurrentTheme];
        if ((theme != nil) && ([theme.options count] > IFSHOptionMainText)) {
            textColour = theme.options[IFSHOptionMainText].colour;
        }
        NSDictionary* messageAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize: 12],
                                            NSForegroundColorAttributeName: textColour,
                                            NSParagraphStyleAttributeName: style};

        // Draw roughly centered
        NSRect bounds = [self bounds];
        NSRect textBounds = NSInsetRect(bounds, 8, 8);
        textBounds.origin.y = NSMinY(bounds) + 8;
        textBounds.size.height = NSMaxY(bounds) - NSMinY(textBounds);

        [message drawInRect: textBounds
             withAttributes: messageAttributes];
    } else {
        // Draw the nodes
        [rootHeaderNode drawNodeInRect: rect
                             withFrame: [self bounds]];
    }
}

#pragma mark - Messages from the header controller

- (void) refreshHeaders: (IFHeaderController*) controller {
    // Get the root header from the controller
    rootHeader = [controller rootHeader];

    // Destroy the editor when the headers are updated
    if (editor) {
        [editor removeFromSuperview];
        editor = nil;
    }

    // Update this control
    [self updateFromRoot];

    if ([delegate respondsToSelector:@selector(refreshHeaders:)]) {
        [delegate refreshHeaders: controller];
    }
}

#pragma mark - Editing events

- (void) editHeaderNode: (IFHeaderNode*) node 
             mouseEvent: (NSEvent*) mouseDown {
    if (editor) {
        [editor removeFromSuperview];
        editor = nil;
    }

    // Stop editing the previous node
    [editNode setEditing: NO];
    [editNode setSelectionStyle: IFHeaderNodeUnselected];
    editNode = nil;

    // Don't edit the title node
    if ([[node header] parent] == nil) return;

    // Start editing the next node
    editNode = node;
    [editNode setSelectionStyle: IFHeaderNodeInputCursor];
    [editNode setEditing: YES];

    [self setNeedsDisplay: YES];

    // Work out the bounding box of the area to be edited
    NSRect headerNameRect = [node headerTitleRect];
    NSRect bounds = [self bounds];
    headerNameRect.size.width = NSMaxX(bounds) - NSMinX(headerNameRect);

    // Assign the field editor to ourselves
    editor = (NSTextView*)[[self window] fieldEditor: YES
                                           forObject: node];

    // Set up the editor storage
    if (!editStorage) editStorage = [[NSTextStorage alloc] init];
    [editStorage setAttributedString: [node attributedTitle]];
    [[editor layoutManager] replaceTextStorage: editStorage];

    // Set up the field editor
    NSColor* bgColour = [editNode textBackgroundColour];
    if (!bgColour) bgColour = backgroundColour;

    [editor setSelectedRange: NSMakeRange(0,0)];
    [editor setDelegate: self];
    [editor setRichText: NO];
    [editor setAllowsDocumentBackgroundColorChange: NO];
    [editor setBackgroundColor: bgColour];
    [editor setHorizontallyResizable: NO];
    [editor setVerticallyResizable: YES];
    [editor setTextContainerInset: NSMakeSize(0, 0)];

    [[editor textContainer] setContainerSize: headerNameRect.size];
    [[editor textContainer] setWidthTracksTextView: NO];
    [[editor textContainer] setHeightTracksTextView: NO];
    [editor setDrawsBackground: NO];
    [editor setTypingAttributes: [editNode attributes]];
    [[editor textContainer] setLineFragmentPadding: 0];

    // Add the field editor
    [editor removeFromSuperview];
    [editor setFrame: headerNameRect];
    [self addSubview: editor];
    [[self window] makeFirstResponder: editor];

    // Set up the editor storage again
    [editStorage setAttributedString: [node attributedTitle]];
    [[editor layoutManager] replaceTextStorage: editStorage];

    // [[editor textStorage] setAttributedString: [node attributedTitle]];

    if (mouseDown) [editor mouseDown: mouseDown];
}

#pragma mark - Mouse events

- (void) mouseDown: (NSEvent*) theEvent {
    // Get the position where the mouse was clicked
    NSPoint viewPos = [self convertPoint: [theEvent locationInWindow]
                                fromView: nil];

    // Get which node was clicked on
    bool headingsVisible = ([[rootHeaderNode children] count] > 0);
    if (headingsVisible) {
        bool editable = false;
        IFHeaderNode* clicked = [rootHeaderNode nodeAtPoint: viewPos
                                                editableOut: &editable];

        if ((clicked != nil) && editable) {
            // Start editing the node
            [self editHeaderNode: clicked
                      mouseEvent: theEvent];
        } else {
            // Inform the delegate that the header has been clicked
            if (clicked && [delegate respondsToSelector: @selector(headerView:clickedOnNode:)]) {
                [delegate headerView: self
                       clickedOnNode: clicked];
            }
        }
    }
}

-(void) mouseMoved:(NSEvent *)theEvent {
    // Get the position where the mouse was clicked
    NSPoint viewPos = [self convertPoint: [theEvent locationInWindow]
                                fromView: nil];

    // Get which node was clicked on
    bool headingsVisible = ([[rootHeaderNode children] count] > 0);
    if (!headingsVisible) {
        [[NSCursor arrowCursor] set];
    }
    else {
        bool editable = false;
        IFHeaderNode* clicked = [rootHeaderNode nodeAtPoint: viewPos
                                                editableOut: &editable];
        if( clicked != nil ) {
            if( editable ) {
                [[NSCursor IBeamCursor] set];
            } else {
                [[NSCursor pointingHandCursor] set];
            }
        } else {
            [[NSCursor arrowCursor] set];
        }
    }
}


#pragma mark - Field editor delegate events

- (void) textDidEndEditing: (NSNotification*) aNotification {
    // Get the new text for this node
    NSString* newText = [editNode freshValueForEditedTitle: [editStorage string]];

    // Tell the delegate to update the source text
    if ([delegate respondsToSelector: @selector(headerView:updateNode:withNewTitle:)]) {
        [delegate headerView: self
                  updateNode: editNode
                withNewTitle: newText];
    }

    // Finished with the edit node
    [editNode setEditing: NO];
    [editNode setSelectionStyle: IFHeaderNodeUnselected];
    editNode = nil;

    // Finished with the field editor
    [editor removeFromSuperview];
    editor = nil;

    [self setNeedsDisplay: YES];

    // Force an immediately update
    [self updateFromRoot];
}


-(void) setColours: (NSColor *) bgColour {
    [self setBackgroundColour: bgColour];
}

@end
