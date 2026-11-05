//
//  IFSkein.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFProject.h"
#import "NSString+IFStringExtensions.h"
#import <Foundation/Foundation.h>
#import "Inform-Swift.h"

@interface IFSkein ()
@property (atomic, weak) IFProject*   project;
@end

#pragma mark - "Skein"
@implementation IFSkein {
    IFSkeinItem*        _rootItem;
    IFSkeinItem*        _activeItem;
    IFSkeinItem*        _winningItem;
    NSMutableString*    currentOutput;
    BOOL                dirtyLayout;        // Does the layout need to be redone?
}

#pragma mark - Initialize
- (instancetype) init { self = [super init]; return self; }

- (instancetype) initWithProject: (IFProject*) theProject {
	self = [super init];

	if (self) {
        _project                     = theProject;
        _rootItem                    = [[IFSkeinItem alloc] initWithSkein: self command: @"- start -"];
		_activeItem                  = nil;
        _winningItem                 = nil;
        _draggingSourceNeedsUpdating = NO;
        _draggingItem                = nil;
		currentOutput                = [[NSMutableString alloc] init];
        _previousCommands            = [[NSMutableArray alloc] init];
        dirtyLayout                  = YES; // Does the skein need laying out?
        _skeinChanged                = YES; // Has the skein actually changed recently?

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(didUndo:)
                                                     name: NSUndoManagerDidUndoChangeNotification
                                                   object: nil];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(didRedo:)
                                                     name: NSUndoManagerDidRedoChangeNotification
                                                   object: nil];
	}

	return self;
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Notifications
-(void) setLayoutDirty {
    dirtyLayout = YES;
}

-(void) setSkeinChanged {
    _skeinChanged = YES;
}

- (void) postSkeinChangedWithAnimate: (BOOL) animate
                   keepActiveVisible: (BOOL) keepActiveVisible
{
    dirtyLayout = NO;
    NSDictionary* userDictionary = @{ IFSkeinChangedAnimateKey: @(animate),
                                   IFSkeinKeepActiveVisibleKey: @(keepActiveVisible) };

    [[NSNotificationCenter defaultCenter] postNotificationName: IFSkeinChangedNotification
                                                        object: self
                                                      userInfo: userDictionary ];
}

// = Output receiver =
#pragma mark - Interpreter Support
- (void) inputCommand: (NSString*) command {
    // Remember the command in a list of commands already played
    [_previousCommands insertObject: command atIndex:0];

    // Disable undo
    [_project.undoManager disableUndoRegistration];

    // Track whether the skein actually changes due to adding this command
    _skeinChanged = NO;

    // Create a new item
    IFSkeinItem* newItem = [[IFSkeinItem alloc] initWithSkein: self command: command];

    // Merge the item into the skein
    IFSkeinItem* mergedItem = [_activeItem addChild: newItem];

    NSAssert((_activeItem == nil) || (_activeItem.skein != nil), @"Active item has no skein #1");

    // Move the 'active' item
    _activeItem = mergedItem;

    NSAssert((_activeItem == nil) || (_activeItem.skein != nil), @"Active item has no skein #2");

    // Create a buffer for any new output
    currentOutput = [[NSMutableString alloc] init];

    // Enable undo, but clear all undo skein commands from the stack. Mark the document as changed if required.
    [_project.undoManager enableUndoRegistration];
    [_project.undoManager removeAllActionsWithTarget: self];
    if( _skeinChanged ) {
        [_project updateChangeCount:NSChangeDone];
    }

    // Notify anyone who's watching that we've updated
    [self postSkeinChangedWithAnimate: NO
                    keepActiveVisible: NO];
}

- (void) inputCharacter: (NSString*) character {
	// We convert characters to their ZSCII equivalent (codes 129-144 and 252-254 for mouse clicks)
	unichar key = 0;

	switch ([character characterAtIndex: 0]) {
		// Arrow keys
		case NSUpArrowFunctionKey:      key = 129; break;
		case NSDownArrowFunctionKey:    key = 130; break;
		case NSLeftArrowFunctionKey:    key = 131; break;
		case NSRightArrowFunctionKey:   key = 132; break;

		// Delete/return
		case NSDeleteFunctionKey:       key = 8;   break;

		// Function keys
		case NSF1FunctionKey:           key = 133; break;
		case NSF2FunctionKey:           key = 134; break;
		case NSF3FunctionKey:           key = 135; break;
		case NSF4FunctionKey:           key = 136; break;
		case NSF5FunctionKey:           key = 137; break;
		case NSF6FunctionKey:           key = 138; break;
		case NSF7FunctionKey:           key = 139; break;
		case NSF8FunctionKey:           key = 140; break;
		case NSF9FunctionKey:           key = 141; break;
		case NSF10FunctionKey:          key = 142; break;
		case NSF11FunctionKey:          key = 143; break;
		case NSF12FunctionKey:          key = 144; break;

		// Mouse buttons (we use fake function keys for this)
		case NSF33FunctionKey:          key = 252; break;
		case NSF34FunctionKey:          key = 254; break;
		case NSF35FunctionKey:          key = 253; break;
	}

	if (key != 0) {
		NSMutableString* newCharacter = [character mutableCopy];

		[newCharacter replaceCharactersInRange: NSMakeRange(0,1)
									withString: [NSString stringWithCharacters: &key
																		length: 1]];
		character = newCharacter;
	}

	[self inputCommand: character];
}

- (void) outputText: (NSString*) outputText {
	// Append this text to the current outout
	[currentOutput appendString: outputText];
}

- (void) waitingForInput {
	// Send the current output to the active item
	if (currentOutput.length > 0) {
        // Disable undo
        [_project.undoManager disableUndoRegistration];

        // Track whether the skein actually changes due to adding the latest output
        _skeinChanged = NO;

        _activeItem = [_activeItem decomposeActual: currentOutput];

        // Enable undo, but clear all undo commands from the stack.
        [_project.undoManager enableUndoRegistration];
        [_project.undoManager removeAllActionsWithTarget: self];

        if( _skeinChanged ) {
            // Mark the document as changed
            [_project updateChangeCount:NSChangeDone];
        }

        [self postSkeinChangedWithAnimate: NO
                        keepActiveVisible: YES];

		currentOutput = [[NSMutableString alloc] init];
	}
}

- (void) interpreterRestart {
    // Reset the list of commands already played
    _previousCommands = [[NSMutableArray alloc] init];

	[self waitingForInput];

	// Back to the top
	_activeItem = _rootItem;

	[self postSkeinChangedWithAnimate: NO
                    keepActiveVisible: NO];
}

- (void) interpreterStop {
    _activeItem = nil;
    [self postSkeinChangedWithAnimate: NO
                    keepActiveVisible: NO];
}

-(BOOL) isTheWinningItem: (IFSkeinItem *) winningItem {
    return _winningItem == winningItem;
}

#pragma mark - Creating an input receiver

+ (id<ZoomViewInputSource>) inputSourceFromSkeinItem: (IFSkeinItem*) item1
                                              toItem: (IFSkeinItem*) item2 {
	// item1 must be a parent of item2, and neither can be nil

    // item1 is not executed
	if (item1 == nil || item2 == nil) return nil;

	NSMutableArray<NSString*>* commandsToExecute = [NSMutableArray array];
    IFSkeinItem* parent = item2;

    while (parent != item1) {
        NSString* cmd = parent.command;
        if (cmd == nil) cmd = @"";
        [commandsToExecute addObject: cmd];

        parent = parent.parent;
        if (parent == nil) return nil;
    }

	// commandsToExecute contains the list of commands we need to execute
    TestCommands* source = [[TestCommands alloc] initWithCommands: commandsToExecute];

	return source;
}

#pragma mark - Create Transcript

- (NSString*) transcriptToPoint: (IFSkeinItem*) item {
	if (item == nil) item = _activeItem;
	
	// Get the list of items
	NSMutableArray* itemList = [NSMutableArray array];
	while (item != nil) {
		[itemList addObject: item];
		
		item = item.parent;
	}
	
	NSMutableString* result = [[NSMutableString alloc] init];
	while (itemList.count > 0) {
		// Retrieve the next item
		IFSkeinItem* thisItem = itemList.lastObject;
		[itemList removeLastObject];
		
		// Add it to the transcript
		if (thisItem != _rootItem) {
			[result appendString: thisItem.command];
			[result appendString: @"\n"];
		}
		if (thisItem.actual != nil) {
			[result appendString: thisItem.actual];
		}
	}
	
	return result;
}

// Return the first node with differences, or the active node
-(IFSkeinItem*) nodeToReport {
    if( _activeItem == nil ) {
        return nil;
    }

    IFSkeinItem* differedItem = _activeItem;
    IFSkeinItem* item = _activeItem;
    while (item != nil) {
        if( item.hasDifferences ) {
            differedItem = item;
        }
        item = item.parent;
    }
    return differedItem;
}

-(NSString*) reportStateForSkein {
    if( !self.rootItem.hasIdeal ) {
        return @"cursed";
    }

    IFSkeinItem* item = _activeItem;
    while (item != nil) {
        if( item.hasDifferences ) {
            return @"wrong";
        }
        item = item.parent;
    }
    return @"right";
}

#pragma mark - Undo Support
-(void) didUndo: (NSNotification*) not {
    // Updates the skein UI after an undo changes the model.

    // All types of undo come through here (e.g. including edits to the story source), so
    // the dirty flag is checked to see if the skein has actually changed before telling it
    // to perform it's layout.
    if( dirtyLayout ) {
        [self postSkeinChangedWithAnimate: YES
                        keepActiveVisible: YES];
    }
}

-(void) didRedo: (NSNotification*) not {
    if( dirtyLayout ) {
        [self postSkeinChangedWithAnimate: YES
                        keepActiveVisible: YES];
    }
}

// Undo helper functions

// When modifying the skein, all undo targets are set to be the IFSkein. This means we can
// remove all skein changes from the undo stack, via [undoManager removeAllActionsWithTarget:]
// but preserve any other types of undos, e.g changes to the source text.
//
// For example: If we play the story, we update the skein as each command is entered (and we
// don't want to undo these changes). We also clear the undo stack of any skein changes (since
// we can't undo them), but leave the undo stack's changes to the source text intact.

- (void) setParentOf: (IFSkeinItem*) item parent: (IFSkeinItem*) newParent {
    item.parent = newParent;
}

-(void) removeFromChildrenArrayOf:(IFSkeinItem*) item itemToRemove: (IFSkeinItem*) itemToRemove {
    [item removeFromChildrenArray: itemToRemove];
}

- (void) addToChildrenArrayOf:(IFSkeinItem*) item itemToAdd: (IFSkeinItem*) itemToAdd {
    [item addToChildrenArray: itemToAdd];
}

- (void) setCommandOf:(IFSkeinItem*) item command:(NSString*) newCommand {
    item.command = newCommand;
}

- (void) setIdealOf:(IFSkeinItem*) item ideal:(NSString*) newIdeal {
    item.ideal = newIdeal;
}

- (void) setActualOf:(IFSkeinItem*) item actual:(NSString*) newActual {
    item.actual = newActual;
}

- (void) setIsTestSubItemWithNSNumberOf:(IFSkeinItem*) item isTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem {
    [item setIsTestSubItemWithNSNumber: newIsTestSubItem];
}

@end

#pragma mark - Dealing with/creating XML data

/// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node)
static NSString* idForNode(IFSkeinItem* item) {
    return [NSString stringWithFormat: @"node-%lu", item.uniqueId];
}

@implementation IFSkein(IFSkeinXML)

// Helper function
+(NSXMLElement*) firstChildOf: (NSXMLElement*) element
                     withName: (NSString*) name {
    NSArray* childrenWithName = [element elementsForName: name];
    if( childrenWithName.count > 0 ) {
        return childrenWithName[0];
    }
    return nil;
}

- (void) decomposeRecursively:(IFSkeinItem*) item {
    if( item && item.isTestSubItem == NO ) {
        [item decompose];
    }
    for(IFSkeinItem* child in item.children) {
        [self decomposeRecursively: child];
    }
}

// Read XML Data into Skein
- (BOOL) parseXmlData: (NSData*) data {
    NSError* error = nil;

    NSXMLDocument* xmlDoc = [[NSXMLDocument alloc] initWithData: data
                                                        options: NSXMLNodeOptionsNone
                                                          error: &error];
    if( error != nil ) {
        NSLog(@"Error reading XML. \"%@\" (code %ld)\n", error, (long) error.code);
        return NO;
    }

    if( ![xmlDoc.rootElement.name isEqualToString:@"Skein"] ) {
        NSLog(@"Could not find root 'Skein' in XML\n");
    }
    NSString* rootNodeId =  [xmlDoc.rootElement attributeForName: @"rootNode"].stringValue;
    if (rootNodeId == nil) {
        NSLog(@"IFSkein: No root node ID specified");
        return NO;
    }

    // Item dictionary: populate with items ready to be linked together
    NSMutableDictionary* itemDictionary = [NSMutableDictionary dictionary];

    NSArray* items = [xmlDoc.rootElement elementsForName: @"item"];

    for( NSXMLElement* item in items ) {
        NSString* itemNodeId =  [item attributeForName: @"nodeId"].stringValue;

        if (itemNodeId == nil) {
            NSLog(@"IFSkein: Warning - found item with no ID");
            continue;
        }

        NSString* command = [IFSkein firstChildOf: item withName: @"command"].stringValue;
        NSString* annotation = [IFSkein firstChildOf: item withName: @"annotation"].stringValue;
        NSString* actual  = [IFSkein firstChildOf: item withName: @"result"].stringValue;
        NSString* ideal   = [IFSkein firstChildOf: item withName: @"commentary"].stringValue;

        if (command == nil) {
            //NSLog(@"IFSkein: Warning: item with no command found");
            command = @"";
        }

        IFSkeinItem* newItem = [[IFSkeinItem alloc] initWithSkein: self command: command];
        if ([annotation startsWith:@"***"]) {
            _winningItem = newItem;
        }
        newItem.actual = actual;
        newItem.ideal = ideal;

        itemDictionary[itemNodeId] = newItem;
    }

    // Item dictionary II: fill in the item children
    for( NSXMLElement* item in items ) {
        NSString* itemNodeId =  [item attributeForName: @"nodeId"].stringValue;

        if (itemNodeId == nil) {
            continue;
        }

        IFSkeinItem* newItem = itemDictionary[itemNodeId];
        if (newItem == nil) {
            // Should never happen
            NSLog(@"IFSkein: item node not found in dictionary (item ID: %@)", itemNodeId);
            return NO;
        }

        // Item children
        NSXMLElement* itemChildren = [IFSkein firstChildOf: item withName: @"children"];
        NSArray* itemKids = [itemChildren elementsForName:@"child"];

        for( NSXMLElement* child in itemKids ) {
            NSString* kidNodeId = [child attributeForName: @"nodeId"].stringValue;
            if (kidNodeId == nil) {
                NSLog(@"IFSkein: Warning: Child item with no node id");
                continue;
            }

            IFSkeinItem* kidItem = itemDictionary[kidNodeId];

            if (kidItem == nil) {
                NSLog(@"IFSkein: Warning: unable to find node %@", kidNodeId);
                continue;
            }

            IFSkeinItem* newKid = [newItem addChild: kidItem];
            itemDictionary[kidNodeId] = newKid;
        }
    }

    // Root item
    IFSkeinItem* newRoot = itemDictionary[rootNodeId];
    if (newRoot == nil) {
        NSLog(@"IFSkein: No root node");
        return NO;
    }

    _rootItem = newRoot;
    _activeItem = nil;

    // Decompose "test me" style commands recursively
    [self decomposeRecursively: _rootItem];

    return YES;
}

#pragma mark - Create XML

// Helper methods
+(NSXMLNode*) addAttribute: (NSXMLElement*) element
                      name: (NSString*) attributeName
                     value: (NSString*) value {
    NSXMLNode * attributeNode = [[NSXMLNode alloc] initWithKind: NSXMLAttributeKind options: NSXMLNodePrettyPrint];
    attributeNode.name        = attributeName;
    attributeNode.stringValue = value;

    [element addAttribute: attributeNode];

    return attributeNode;
}

+(NSXMLElement*) elementWithName: (NSString*) elementName
                   attributeName: (NSString*) attributeName
                  attributeValue: (NSString*) attributeValue {
    NSXMLElement* root = [[NSXMLElement alloc] initWithKind: NSXMLElementKind options:NSXMLNodePrettyPrint];
    root.name = elementName;
    [IFSkein addAttribute: root
                     name: attributeName
                    value: attributeValue];
    return root;
}

+(NSXMLElement*) elementWithName: (NSString*) elementName
                           value: (NSString*) value
              preserveWhitespace: (BOOL) preserveWhitespace {
    NSUInteger options = preserveWhitespace ? NSXMLNodePreserveWhitespace : 0;
    options |= NSXMLNodePrettyPrint;
    NSXMLElement* root = [[NSXMLElement alloc] initWithKind: NSXMLElementKind
                                                    options: options];
    if( preserveWhitespace ) {
        [IFSkein addAttribute: root
                         name: @"xml:space"
                        value: @"preserve"];
    }
    root.name        = elementName;
    root.stringValue = value;

    return root;
}

- (NSString*) getXMLString {
    NSXMLElement* root = [IFSkein elementWithName: @"Skein"
                                    attributeName: @"rootNode"
                                   attributeValue: idForNode(_rootItem)];

    NSXMLDocument* xmlDoc = [[NSXMLDocument alloc] initWithKind: NSXMLDocumentKind
                                                        options: NSXMLDocumentTidyXML | NSXMLNodePrettyPrint];
    xmlDoc.rootElement = root;

    NSString* version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleGetInfoString"];
    NSString* generator = [NSString stringWithFormat:@"Inform Mac Client (%@)", version];
    [root addChild: [IFSkein elementWithName: @"generator" value: generator preserveWhitespace: NO]];

    // Write items
    NSMutableArray* itemStack = [NSMutableArray array];
    [itemStack addObject: _rootItem];

    while (itemStack.count > 0) {
        // Pop from the stack
        IFSkeinItem* node = itemStack.lastObject;
        [itemStack removeLastObject];

        // Push any children of this node
        [itemStack addObjectsFromArray: node.children];

        // We only output non-test nodes
        if( !node.isTestSubItem ) {
            // Add XML
            NSXMLElement* item = [IFSkein elementWithName: @"item"
                                            attributeName: @"nodeId"
                                           attributeValue: idForNode(node)];
            if (node.command != nil) {
                [item addChild: [IFSkein elementWithName: @"command" value: node.command preserveWhitespace: YES]];
            }
            NSString* composedActual = node.composedActual;
            NSString* composedIdeal  = node.composedIdeal;
            [item addChild: [IFSkein elementWithName: @"result"  value: composedActual preserveWhitespace: YES]];
            [item addChild: [IFSkein elementWithName: @"commentary" value: composedIdeal preserveWhitespace: YES]];

            if (_winningItem == node) {
                [item addChild: [IFSkein elementWithName: @"annotation" value: @"***" preserveWhitespace: YES]];
            }

            [root addChild: item];

            if ((node.children).count > 0) {
                NSXMLElement* children = [IFSkein elementWithName: @"children" value: @"" preserveWhitespace: NO];
                [item addChild: children];

                for( IFSkeinItem* childNode in node.nonTestChildren ) {
                    [children addChild: [IFSkein elementWithName: @"child"
                                                   attributeName: @"nodeId"
                                                  attributeValue: idForNode(childNode)]];
                }
            }
        }
    }

    return [xmlDoc XMLStringWithOptions: NSXMLNodePrettyPrint];
}

@end
