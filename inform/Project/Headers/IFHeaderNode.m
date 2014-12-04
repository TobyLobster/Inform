//
//  IFHeaderNode.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 03/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFHeaderNode.h"

// = Fonts =

static NSFont* headerNodeFont = nil;
static NSFont* boldHeaderNodeFont = nil;
static NSString* bulletPoint = nil;

// = Preferences =

static NSString* IFHeaderPointSize	= @"IFHeaderPointSize";
static NSString* IFHeaderMargin		= @"IFHeaderMargin";
static NSString* IFHeaderIndent		= @"IFHeaderIndent";
static NSString* IFHeaderGap		= @"IFHeaderGap";
static NSString* IFHeaderCorner		= @"IFHeaderCorner";

static float pointSize = 11.0;

@implementation IFHeaderNode

// = Class initialization =

+ (void) initialize {
	// Register the preferences for this class
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithFloat: [NSFont smallSystemFontSize]],	IFHeaderPointSize,
			[NSNumber numberWithFloat: 5],								IFHeaderMargin,
			[NSNumber numberWithFloat: 12],								IFHeaderIndent,
			[NSNumber numberWithFloat: 8],								IFHeaderGap,
			[NSNumber numberWithFloat: 5],								IFHeaderCorner,
			nil]];
	
	pointSize = [[[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderPointSize] floatValue];
}

// = Utilities used to help lay out this node =

- (NSFont*) font {
	if (depth == 0) return boldHeaderNodeFont;
	
	switch (selected) {
		case IFHeaderNodeSelected:
			return boldHeaderNodeFont;
			
		default:
			return headerNodeFont;
	}
}

- (NSString*) name {
	NSString* name = [header headingName];
	if (depth > 0) {
		name = [bulletPoint stringByAppendingString: name];
	}
	return name;
}

- (void) updateNodeFrame {
	// The frame has an origin at the position specified for this node
	frame.origin = position;
	
	// The initial height is determined by the title of this node
	frame.size.width = [[self name] sizeWithAttributes: [self attributes]].width;
	frame.size.height = gap + [[self font] ascender] - [[self font] descender];
    
    exclusiveFrame = frame;
	
	// The total height is different if there are children for this item (depending on the y position of the final child)
	if (children && [children count] > 0) {
		// The width is that of the widest child element
		float maxX = NSMaxX(frame);
		
		for( IFHeaderNode* child in children ) {
			float childMaxX = NSMaxX([child frame]);
			if (childMaxX > maxX) maxX = childMaxX;
		}
		
		frame.size.width = maxX - NSMinX(frame);

		// The height is based on the maximum Y position of the final child
		NSRect lastFrame = [(IFHeaderNode*)[children lastObject] frame];
		float maxY = NSMaxY(lastFrame);
		frame.size.height = maxY - NSMinY(frame);
	}
}

// = Constructing this node =

- (id) initWithHeader: (IFHeader*) newHeader
			 position: (NSPoint) newPosition
				depth: (int) newDepth {
	self = [self init];
	
	if (self) {
		// If the fonts don't exist, then update them
		if (!headerNodeFont)		headerNodeFont		= [[NSFont systemFontOfSize: pointSize] retain];
		if (!boldHeaderNodeFont)	boldHeaderNodeFont	= [[NSFont boldSystemFontOfSize: pointSize] retain];
		
		// Create a bullet point
		if (!bulletPoint) {
			unichar bulletPointChars[] = { 0x20, 0x2022, 0x20, 0 };
			bulletPoint = [[NSString alloc] initWithCharacters: bulletPointChars
														length: 3];
		}
		
		// Update the contents of this node
		header = [newHeader retain];
		depth = newDepth;
		position = newPosition;
		selected = IFHeaderNodeUnselected;
		
		children = nil;
		
		// Set up the parameters
		margin	= [[[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderMargin] floatValue];
		indent	= [[[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderIndent] floatValue];
		gap		= [[[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderGap] floatValue];
		corner	= [[[NSUserDefaults standardUserDefaults] objectForKey: IFHeaderCorner] floatValue];
	}
	
	return self;
}

- (void) dealloc {
	[header release];			header = nil;
	[children release];			children = nil;
	
	[super dealloc];
}

- (void) populateToDepth: (int) maxDepth {
	// Do nothing if we've reached the end
	if (maxDepth <= [[header symbol] level]) {
		[children release]; children = nil;
		[self updateNodeFrame];
		return;
	}
	
	// Create the children array
	[children release]; children = nil;
	[self updateNodeFrame];
	children = [[NSMutableArray alloc] init];
	
	// Work out the position for the first child node
	NSPoint childPoint = NSMakePoint(NSMinX(frame), floorf(NSMaxY(frame)));
	
	// Populate it
	for( IFHeader* childNode in [header children] ) {
		if ([[childNode symbol] level] > maxDepth) continue;
		
		// Create a new child node
		IFHeaderNode* newChildNode = [[IFHeaderNode alloc] initWithHeader: childNode
																 position: childPoint
																	depth: depth+1];
		[newChildNode autorelease];
		
		// Populate it
		[newChildNode populateToDepth: maxDepth];
		[children addObject: newChildNode];
		
		// Update the position of the next child element
		childPoint.y = floorf(NSMaxY([newChildNode frame]));
	}
	
	// Update the frame of this node
	[self updateNodeFrame];
}

// = Getting information about this node =

- (NSRect) frame {
	return frame;
}

- (IFHeader*) header {
	return header;
}

- (IFHeaderNodeSelectionStyle) selectionStyle {
	return selected;
}

- (void) setSelectionStyle: (IFHeaderNodeSelectionStyle) selectionStyle {
	selected = selectionStyle;
}

- (NSArray*) children {
	if (!children || [children count] == 0) return nil;
	return children;
}

- (IFHeaderNode*) nodeAtPoint: (NSPoint) point
                  editableOut: (bool*) editableOut {
    NSRect indentedFrame = frame;
    indentedFrame.origin.x += margin + depth * indent;

	// If the point is outside the frame for this node, then return nothing
    if( NSPointInRect(point, indentedFrame) ) {
        // If the point is beyond the line border for this item, then search the children
        for( IFHeaderNode* child in children ) {
            IFHeaderNode* childNode = [child nodeAtPoint: point
                                             editableOut: editableOut];
            if (childNode) {
                return childNode;
            }
        }
    }
	
    // Editable section
	if( NSPointInRect(point, [self fullHeaderTitleRect]) ) {
        *editableOut = true;
        return self;
    }
    
    
    // Non-editable section
    indentedFrame = exclusiveFrame;
    indentedFrame.origin.x += margin + depth * indent;
    
	// If within the frame and not any of the children, then the node that was clicked was this node
	if( NSPointInRect(point, indentedFrame) ) {
        *editableOut = false;
        return self;
    }

    *editableOut = false;
    return nil;
}

- (IFHeaderNode*) nodeWithLines: (NSRange) lines
					  intelFile: (IFIntelFile*) intel {
	// FIXME: this more properly belongs in IFHeader (? - won't take account of current child settings there)
	
	// Get the following symbol
	IFIntelSymbol* symbol = [header symbol];
	IFIntelSymbol* followingSymbol = [symbol sibling];
	
	if (!followingSymbol) {
		IFIntelSymbol* parent = [symbol parent];
		
		while (parent && !followingSymbol) {
			followingSymbol = [parent sibling];
			parent = [parent parent];
		}
	}

	// Work out the line range for this header node
	unsigned int firstLine;
	unsigned int finalLine;
	
	firstLine = [intel lineForSymbol: symbol];
	if (followingSymbol) {
		finalLine = [intel lineForSymbol: followingSymbol];
	} else {
		finalLine = NSNotFound;
	}
	
	// If this range does not overlap the symbol range for this symbol, then return nil
	if (symbol) {
		if (firstLine >= lines.location + lines.length) return nil;
		if (firstLine > lines.location) return nil;
		if (finalLine != NSNotFound && lines.location > finalLine) return nil;
	}
	
	// See if any of the child nodes are better match
	if (children) {
		for( IFHeaderNode* childNode in children ) {
			IFHeaderNode* foundChild = [childNode nodeWithLines: lines
													  intelFile: intel];
			if (foundChild) return foundChild;
		}
	}
	
	// This is the header node to use
	return self;
}

// = Drawing the node =

- (NSBezierPath*) highlightPathForFrame: (NSRect) drawFrame {
	// Bezier path representing the outline of this node
	NSBezierPath* result = [NSBezierPath bezierPath];
	
	// Draw the border
	[result moveToPoint: NSMakePoint(NSMinX(frame) + corner + margin + indent * depth + .5, NSMinY(frame) + .5)];
	[result lineToPoint: NSMakePoint(NSMaxX(drawFrame) - corner - margin + .5, NSMinY(frame) + .5)];
	[result curveToPoint: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMinY(frame) + corner + .5)
		   controlPoint1: NSMakePoint(NSMaxX(drawFrame) - corner/2 - margin + .5, NSMinY(frame) + .5)
		   controlPoint2: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMinY(frame) + corner/2 + .5)];

	[result lineToPoint: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMaxY(frame) - corner + .5)];
	[result curveToPoint: NSMakePoint(NSMaxX(drawFrame) - corner - margin + .5, NSMaxY(frame) + .5)
		   controlPoint1: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMaxY(frame) - corner/2 + .5)
		   controlPoint2: NSMakePoint(NSMaxX(drawFrame) - corner/2 - margin, NSMaxY(frame))];

	[result lineToPoint: NSMakePoint(NSMinX(frame) + corner + margin + indent * depth + .5, NSMaxY(frame) + .5)];
	[result curveToPoint: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMaxY(frame) - corner + .5)
		   controlPoint1: NSMakePoint(NSMinX(frame) + corner/2 + margin + indent * depth + .5, NSMaxY(frame) + .5)
		   controlPoint2: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMaxY(frame) - corner/2 + .5)];
	
	[result lineToPoint: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMinY(frame) + corner + .5)];
	[result curveToPoint: NSMakePoint(NSMinX(frame) + corner + margin + indent * depth + .5, NSMinY(frame) + .5)
		   controlPoint1: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMinY(frame) + corner/2 + .5)
		   controlPoint2: NSMakePoint(NSMinX(frame) + corner/2 + margin + indent * depth + .5, NSMinY(frame) + .5)];
	
	return result;
}

- (NSBezierPath*) truncatedHighlightPathForFrame: (NSRect) drawFrame {
	float height = gap + [[self font] ascender] - [[self font] descender];
	if (height + corner >= frame.size.height) {
		return [self highlightPathForFrame: drawFrame];
	}
	
	// Bezier path representing the outline of this node
	NSBezierPath* result = [NSBezierPath bezierPath];
	
	// Draw the border
	[result moveToPoint: NSMakePoint(NSMinX(frame) + corner + margin + indent * depth + .5, NSMinY(frame) + .5)];
	[result lineToPoint: NSMakePoint(NSMaxX(drawFrame) - corner - margin + .5, NSMinY(frame) + .5)];
	[result curveToPoint: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMinY(frame) + corner + .5)
		   controlPoint1: NSMakePoint(NSMaxX(drawFrame) - corner/2 - margin + .5, NSMinY(frame) + .5)
		   controlPoint2: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMinY(frame) + corner/2 + .5)];
	
	[result lineToPoint: NSMakePoint(NSMaxX(drawFrame) - margin + .5, NSMinY(frame) + height + .5)];
	[result lineToPoint: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMinY(frame) + height + .5)];
	
	[result lineToPoint: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMinY(frame) + corner + .5)];
	[result curveToPoint: NSMakePoint(NSMinX(frame) + corner + margin + indent * depth + .5, NSMinY(frame) + .5)
		   controlPoint1: NSMakePoint(NSMinX(frame) + margin + indent * depth + .5, NSMinY(frame) + corner/2 + .5)
		   controlPoint2: NSMakePoint(NSMinX(frame) + corner/2 + margin + indent * depth + .5, NSMinY(frame) + .5)];
	
	return result;
}

- (NSDictionary*) attributes { 
	return [NSDictionary dictionaryWithObjectsAndKeys:
			 [self font], NSFontAttributeName,
			 nil];
}

- (int) uneditablePartLength {
	NSString* name = [self name];
	int x;
	
	int spaceCount = 0;
	for (x=0; x<[name length]; x++) {
		if ([name characterAtIndex: x] == ' ') {
			spaceCount++;
		}
		if (spaceCount == 3) break;
	}
	if (x >= [name length]) return x;
	
	// x is now the position of the 3rd space (which should correspond to the part of the string ' * Part ')
	return x+1;
}

- (NSString*) editableName {
	// Get the editable portion of the string
	NSString* editable = [[self name] substringFromIndex: [self uneditablePartLength]];
	
	// Strip off any trailing spaces
	if ([editable characterAtIndex: [editable length]-1] == '\n') {
		editable = [editable substringToIndex: [editable length]-1];
	}
	
	// Return the result
	return editable;
}

- (NSString*) freshValueForEditedTitle: (NSString*) edited {
	return [[[[[self name] substringToIndex: [self uneditablePartLength]] 
			  substringFromIndex: [bulletPoint length]]
			 stringByAppendingString: edited] 
			stringByAppendingString: @"\n"];
}

- (void) setEditing: (BOOL) newEditing {
	editing = newEditing;
}

- (NSColor*) textBackgroundColour {
	// Draw the node background, if necessary
	NSColor* nodeBackgroundColour = nil;
	
	switch (selected) {
		case IFHeaderNodeSelected:
			nodeBackgroundColour = [NSColor selectedTextBackgroundColor];
			break;
			
		case IFHeaderNodeInputCursor:
			nodeBackgroundColour = [NSColor grayColor];
			break;
			
		default:
			break;
	}
	
	if (nodeBackgroundColour) {
		// Pick the colours that we'll use to do the drawing
		NSColor* nodeTextBgColour = [nodeBackgroundColour colorWithAlphaComponent: 0.8];
		return nodeTextBgColour;
	}
	
	return nil;
}

- (NSAttributedString*) attributedTitle {
	NSAttributedString* result = [[NSAttributedString alloc] initWithString: [self editableName]
																 attributes: [self attributes]];
	return [result autorelease];
}

- (NSRect) fullHeaderTitleRect {
	NSString* uneditablePortion = [[self name] substringToIndex: [self uneditablePartLength]];
	NSString* editablePortion = [self editableName];
	
	NSSize uneditableSize = [uneditablePortion sizeWithAttributes: [self attributes]];
	NSSize nameSize = [editablePortion sizeWithAttributes: [self attributes]];
	return NSMakeRect(frame.origin.x + margin + depth*indent + uneditableSize.width,
                      frame.origin.y,
                      nameSize.width,
                      gap + [[self font] ascender] - [[self font] descender]);
}

- (NSRect) headerTitleRect {
	NSString* uneditablePortion = [[self name] substringToIndex: [self uneditablePartLength]];
	NSString* editablePortion = [self editableName];
	
	NSSize uneditableSize = [uneditablePortion sizeWithAttributes: [self attributes]];
	NSSize nameSize = [editablePortion sizeWithAttributes: [self attributes]];
	return NSMakeRect(frame.origin.x + margin + depth*indent + uneditableSize.width,
                      frame.origin.y + floorf(gap/2),
                      nameSize.width,
                      nameSize.height);
}

- (void) drawNodeInRect: (NSRect) rect
			  withFrame: (NSRect) drawFrame {
	// Do nothing if this node is outside the draw rectangle
	if (!NSIntersectsRect(rect, frame)) {
		return;
	}
	
	// Draw the node background, if necessary
	NSColor* nodeBackgroundColour = nil;
	
	switch (selected) {
		case IFHeaderNodeSelected:
			nodeBackgroundColour = [NSColor selectedTextBackgroundColor];
			break;

		case IFHeaderNodeInputCursor:
			nodeBackgroundColour = [NSColor grayColor];
			break;
			
		default:
			break;
	}
	
	if (nodeBackgroundColour) {
		// Pick the colours that we'll use to do the drawing
		NSColor* nodeLineColour = nodeBackgroundColour;
		NSColor* nodeTextBgColour = [nodeBackgroundColour colorWithAlphaComponent: 0.8];
		NSColor* nodeChildBgColour = [nodeBackgroundColour colorWithAlphaComponent: 0.2];
		
		// Create a bezier path representing this node
		NSBezierPath* highlightPath = [self highlightPathForFrame: drawFrame];
		NSBezierPath* textHighlightPath = [self truncatedHighlightPathForFrame: drawFrame];
		
		// Draw it
		[nodeChildBgColour set];	[highlightPath fill];
		[nodeTextBgColour set];		[textHighlightPath fill];
		[nodeLineColour set];		[highlightPath stroke];
	}

	// If editing, then only draw the uneditable part of the name
	NSString* name;
	if (editing) {
		name = [[self name] substringToIndex: [self uneditablePartLength]];
	} else {
		name = [self name];
	}
	
	// Draw the node title, truncating if necessary
	[name drawAtPoint: NSMakePoint(frame.origin.x + margin + depth * indent, frame.origin.y + floorf(gap/2))
	   withAttributes: [self attributes]];
	
	// Draw the node children
	if (children && [children count] > 0) {
		IFHeaderNode* lastChild;
		
		lastChild = nil;
		
        for( IFHeaderNode* child in children ) {
			// Draw this child
			[child drawNodeInRect: rect
						withFrame: drawFrame];
			
			// Draw a line linking this child to the last child if possible
			if (lastChild && [lastChild children] && [lastChild selectionStyle] == IFHeaderNodeUnselected) {
				[[NSColor colorWithDeviceWhite: 0.8
										 alpha: 1.0] set];
				
				NSPoint lineStart = [lastChild frame].origin;
				NSPoint lineEnd = [child frame].origin;
				
				lineStart.x	+= margin + 6 + (depth+1)*indent + 0.5;
				lineEnd.x	+= margin + 6 + (depth+1)*indent + 0.5;
				
				lineStart.y	+= [[lastChild font] ascender] - [[lastChild font] descender] + gap - 1;
				lineEnd.y	+= gap;
				
				[NSBezierPath strokeLineFromPoint: lineStart
										  toPoint: lineEnd];
			}
			
			// Move on
			lastChild = child;
		}

		// Draw a line linking this child to the last child if possible
		if (lastChild && [lastChild children] && [lastChild selectionStyle] == IFHeaderNodeUnselected) {
			[[NSColor colorWithDeviceWhite: 0.8
									 alpha: 1.0] set];
			
			NSRect lastFrame = [lastChild frame];
			NSPoint lineStart = lastFrame.origin;
			NSPoint lineEnd = NSMakePoint(NSMinX(lastFrame), NSMaxY(lastFrame));
			
			lineStart.x	+= margin + 6 + (depth+1)*indent + 0.5;
			lineEnd.x	+= margin + 6 + (depth+1)*indent + 0.5;
			
			lineStart.y	+= [[lastChild font] ascender] - [[lastChild font] descender] + gap - 1;
			lineEnd.y	-= gap/2;
			
			[NSBezierPath strokeLineFromPoint: lineStart
									  toPoint: lineEnd];
		}
	}
}

@end
