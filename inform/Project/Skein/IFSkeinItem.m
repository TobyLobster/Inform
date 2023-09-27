//
//  IFSkeinItem.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>
#import "IFSkeinItem.h"
#import "IFUtility.h"
#import "IFDiffer.h"
#import "IFProject.h"
#import "IFSkein.h"

// Paseboard type for drag and drop
NSString* const IFSkeinItemPboardType = @"com.inform7.IFSkeinItemPboardType";

#pragma mark - "Skein Item"
@implementation IFSkeinItem {
    NSMutableArray* _children;
    unsigned long   differencesHash;        // Hash to work out if differences need recalculating
}

@synthesize command         = _command;
@synthesize ideal           = _ideal;
@synthesize actual          = _actual;
@synthesize parent          = _parent;
@synthesize isTestSubItem   = _isTestSubItem;
@synthesize diffCachedResult = _diffCachedResult;

#pragma mark - Initialization
- (instancetype) init {
    self = [super init];
    if(self) {
        _diffCachedResult = NULL;
        differencesHash = 0;
        _children = NULL;
        // I don't think we use this init...
        assert(false);
    }
    return self;
}

- (instancetype) initWithSkein: (IFSkein*) skein
                       command: (NSString*) com {
	self = [super init];

	if (self) {
        _uniqueId       = [IFUtility generateID];
        _command        = [[self class] sanitizeCommand: com];
		_actual         = @"";
        _ideal          = @"";
        _isTestSubItem  = NO;
        _skein          = skein;

		_parent         = nil;
		_children       = [[NSMutableArray alloc] init];

        // Command size
		_commandSizeDidChange = YES;

        // Differences
        differencesHash  = 0;
        _diffCachedResult = [[IFDiffer alloc] init];
	}

	return self;
}

#pragma mark - NSCoding
- (void) encodeWithCoder: (NSCoder*) encoder {
    [encoder encodeObject: _children    forKey: @"children"];
    [encoder encodeObject: _command     forKey: @"command"];
    [encoder encodeObject: _actual      forKey: @"result"];
    [encoder encodeBool: _isTestSubItem forKey: @"isTestSubItem"];
}

- (instancetype)initWithCoder: (NSCoder *)decoder {
    self = [super init];

    if (self) {
        _uniqueId           = [IFUtility generateID];
        _children           = [decoder decodeObjectOfClasses: [NSSet setWithObjects: [NSMutableArray class], [IFSkeinItem class], nil] forKey: @"children"];
        _command            = [decoder decodeObjectOfClass: [NSString class] forKey: @"command"];
        _actual             = [decoder decodeObjectOfClass: [NSString class] forKey: @"result"];
        _isTestSubItem      = [decoder decodeBoolForKey:   @"isTestSubItem"];
        _diffCachedResult   = [[IFDiffer alloc] init];
        differencesHash     = 0;
        _commandSizeDidChange = YES;

        for( IFSkeinItem* child in _children ) {
            child->_parent = self;
        }
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - Class Helpers
// Sanitize the command: ensure it contains no control characters and no trailing whitespace
+(NSString*) sanitizeCommand: (NSString*) command {
    if (command == nil) return @"";

    // Replace all Unicode control characters (0x00-0x1f and 0x7f-0x9f) with spaces
    NSArray* components = [command componentsSeparatedByCharactersInSet: [NSCharacterSet controlCharacterSet]];
    command = [components componentsJoinedByString:@" "];

    // Remove trailing whitespace
    return command.stringByRemovingTrailingWhitespace;
}

+(NSString*) stringByRemovingPrompt: (NSString*) string
{
    if( string == nil ) {
        return @"";
    }
    NSInteger lastCarriageReturnIndex = [string lastIndexOf: @"\n"];
    if( lastCarriageReturnIndex == NSNotFound ) {
        return string;
    }
    return [string substringToIndex: lastCarriageReturnIndex];
}

+(NSString*) promptForString: (NSString*) string
{
    if( string == nil ) {
        return @"";
    }
    NSInteger lastCarriageReturnIndex = [string lastIndexOf: @"\n"];
    if( lastCarriageReturnIndex == NSNotFound ) {
        return @"";
    }
    return [string substringFromIndex: lastCarriageReturnIndex + 1];
}

#pragma mark - Access to Document
-(IFProject*) document {
    // Look through all documents
    NSArray* docs = [NSDocumentController sharedDocumentController].documents;
    for( NSDocument* doc in docs ) {
        if( [doc isKindOfClass: [IFProject class]] ) {
            IFProject* project = (IFProject*) doc;

            // Look through all skeins in each document looking for our root item
            for( IFSkein* skein in project.skeins ) {
                if( skein == _skein ) {
                    return project;
                }
            }
        }
    }
    return nil;
}

#pragma mark - Undo Manager
-(NSUndoManager*) undoManager {
    return (self.document).undoManager;
}

-(void) disableUndo {
    [self.undoManager disableUndoRegistration];
}

-(void) enableUndo {
    [self.undoManager enableUndoRegistration];
}

#pragma mark - Properties

- (NSArray*) children {
	return [_children copy];
}

- (NSArray*) nonTestChildren {
    IFSkeinItem* item = self;
    while( item.children.count > 0 )
    {
        IFSkeinItem* child = item.children[0];
        if( !child.isTestSubItem ) {
            return item.children;
        }
        item = child;
    }
    return nil;
}

- (IFSkeinItem*) childWithCommand: (NSString*) com isTestSubItem:(BOOL) isTestSubItem {

    for( IFSkeinItem* childItem in _children ) {
        if ([childItem.command isEqualToString: com]) {
            if( childItem.isTestSubItem == isTestSubItem ) {
                return childItem;
            }
        }
    }

    return nil;
}

-(IFSkeinItem*) rootItem {
    IFSkeinItem* item = self;
    while (item.parent != nil ) {
        item = item.parent;
    }
    return item;
}

-(BOOL) hasDescendant:(IFSkeinItem*) child {
    IFSkeinItem* item = child;
    while (item != nil ) {
        if( item == self ) {
            return YES;
        }
        item = item.parent;
    }
    return NO;
}

// Calculate a hash based on the current state. We only redraw the report when the hash changes.
-(unsigned long) reportStateHash {
    NSUInteger hash =_ideal.hash;
    hash ^= _actual.hash + 1;
    hash ^= _command.hash + 2;

    return hash;
}

#pragma mark - Changing the Skein
- (void) setParent: (IFSkeinItem*) newParent {
    if( _parent == newParent) {
        return;
    }

    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setParentOf: self parent: _parent];
    _parent = newParent;
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
    if( newParent.skein != _skein ) {
        _skein = newParent.skein;
        [_skein setLayoutDirty];
        [_skein setSkeinChanged];
    }
}

- (void) removeFromParent {
    if( _parent ) {
        [_parent removeFromChildrenArray: self];
        if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setParentOf: self parent: _parent];
        [_skein setLayoutDirty];
        [_skein setSkeinChanged];
        _parent = nil;
        [self setSkeinRecursively: nil];
    }
}

-(void) removeFromChildrenArray:(IFSkeinItem*) itemToRemove {
    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] addToChildrenArrayOf: self itemToAdd: itemToRemove];
    [_children removeObject: itemToRemove];
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

-(void) addToChildrenArray:(IFSkeinItem*) itemToAdd {
    // Insert childItem into children alphabetically
    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] removeFromChildrenArrayOf: self itemToRemove: itemToAdd];
    int index;
    for( index = 0; index < _children.count; index++ ) {
        if( [[_children[index] command] compare: itemToAdd.command] == NSOrderedDescending ) {
            break;
        }
    }
    [_children insertObject: itemToAdd
                    atIndex: index];
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

- (void) mergeWith: (IFSkeinItem*) newItem {
    // Make a local copy of the children
    NSMutableArray* localChildren = [[NSMutableArray alloc] init];
    for( IFSkeinItem* childItem in newItem.children ) {
        [localChildren addObject: childItem];
    }

	// Merges this item with another
    for( IFSkeinItem* childItem in localChildren ) {
        IFSkeinItem* oldChild = [self childWithCommand: childItem.command isTestSubItem: childItem.isTestSubItem];

        if (oldChild == nil) {
            [self addChild: childItem];
        } else {
            [oldChild mergeWith: childItem];
        }
	}
}

-(void) setSkeinRecursively:(IFSkein*) newSkein {
    _skein = newSkein;
    for( IFSkeinItem* child in _children ) {
        [child setSkeinRecursively: newSkein];
    }
}

- (IFSkeinItem*) addChild: (IFSkeinItem*) childItem {
    // Is there an existing child with the same command?
    IFSkeinItem* oldChild = [self childWithCommand: childItem.command isTestSubItem: childItem.isTestSubItem];

	if (oldChild != nil) {
		// Merge because this child item already exists
		[oldChild mergeWith: childItem];

        NSString* newActual   = (childItem.actual.length > 0) ? childItem.actual : oldChild.actual;
        NSString* newIdeal    = (childItem.ideal.length > 0)  ? childItem.ideal  : oldChild.ideal;
        BOOL      newTestNode = childItem.isTestSubItem;

		// Copy any new state over to the existing item
        oldChild.actual         = newActual;
        oldChild.ideal          = newIdeal;
        oldChild.isTestSubItem  = newTestNode;

        return oldChild;
	}

    // Otherwise, just add the new item
    [childItem removeFromParent];
    childItem.parent = self;
    [childItem setSkeinRecursively: _skein];

    [self addToChildrenArray: childItem];

    return childItem;
}

#pragma mark - Item Data

- (void) setCommand: (NSString*) newCommand {
    newCommand = [[self class] sanitizeCommand: newCommand];

    if ([newCommand isEqualToString: _command]) {
        return;
    }

    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setCommandOf: self command: _command];

    _commandSizeDidChange = YES;
    _command = newCommand;
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

- (void) setActual: (NSString *) newActual {
    if(newActual == nil) newActual = @"";

    if( [newActual isEqualToString: _actual] ) {
        return;
    }

    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setActualOf: self actual: _actual];
    _actual = newActual;
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

- (void) setIdeal: (NSString *) newIdeal {
    if(newIdeal == nil) newIdeal = @"";
    if( [newIdeal isEqualToString: _ideal] ) {
        return;
    }

    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setIdealOf: self ideal: _ideal];
    _ideal = newIdeal;
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

- (void) setIsTestSubItem: (BOOL)newIsTestSubItem {
    [self setIsTestSubItemWithNSNumber:@(newIsTestSubItem)];
}

- (void) setIsTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem {
    if( _isTestSubItem == newIsTestSubItem.boolValue) {
        return;
    }

    if( _skein ) [[self.undoManager prepareWithInvocationTarget: _skein] setIsTestSubItemWithNSNumberOf: self
                                                                              isTestSubItemWithNSNumber: @(_isTestSubItem)];
    _isTestSubItem = newIsTestSubItem.boolValue;
    [_skein setLayoutDirty];
    [_skein setSkeinChanged];
}

#pragma mark - Differences
-(IFDiffer*) differences {
    unsigned long newHash = self.reportStateHash;

    if(( differencesHash == 0 ) || (differencesHash != newHash)) {
        NSString* localIdeal  = self.ideal;
        NSString* localActual = self.actual;
        if( localIdeal == nil )  localIdeal = @"";
        if( localActual == nil ) localActual = @"";

        // Preprocess the strings to remove matching prompts and trim matching whitespace
        // Remove matching prompts
        BOOL promptsMatch            = [[IFSkeinItem promptForString: localActual] isEqualToString: [IFSkeinItem promptForString: _ideal]];
        BOOL idealHasStandardPrompt  = [localIdeal endsWith:@"\n>"];
        BOOL actualHasStandardPrompt = [localActual endsWith:@"\n>"];
        BOOL hasIdealOutput          = localIdeal.length > 0;
        BOOL hasActualOutput         = localActual.length > 0;
        BOOL canRemovePrompt         = promptsMatch || (!hasActualOutput && idealHasStandardPrompt) || (!hasIdealOutput && actualHasStandardPrompt);
        if( canRemovePrompt ) {
            localIdeal  = [IFSkeinItem stringByRemovingPrompt: localIdeal];
            localActual = [IFSkeinItem stringByRemovingPrompt: localActual];
        }

        // Remove matching trailing whitespace
        NSString* idealTrailingWhitespace  = localIdeal.trailingWhitespace;
        NSString* actualTrailingWhitespace = localActual.trailingWhitespace;
        if( [idealTrailingWhitespace isEqualToString: actualTrailingWhitespace] || !hasIdealOutput || !hasActualOutput) {
            localIdeal  = localIdeal.stringByRemovingTrailingWhitespace;
            localActual = localActual.stringByRemovingTrailingWhitespace;
        }

        // Remove matching leading whitespace
        NSString* idealLeadingWhitespace  = localIdeal.leadingWhitespace;
        NSString* actualLeadingWhitespace = localActual.leadingWhitespace;
        if( [idealLeadingWhitespace isEqualToString: actualLeadingWhitespace] || !hasIdealOutput || !hasActualOutput) {
            localIdeal  = localIdeal.stringByRemovingLeadingWhitespace;
            localActual = localActual.stringByRemovingLeadingWhitespace;
        }

        [_diffCachedResult diffIdeal: localIdeal
                             actual: localActual ];
        differencesHash = newHash;
    }
    return _diffCachedResult;
}

-(BOOL) hasDifferences {
    return self.differences.differences.count > 0;
}

-(BOOL) hasIdeal {
    return (self.ideal != nil) && (self.ideal.length > 0);
}

-(BOOL) hasBadge {
    return self.hasIdeal && self.hasDifferences;
}

// = Composing and decomposing "Test me" style nodes into separate items =
#pragma mark - Composing and Decomposing "test me" Style Nodes
+(NSArray*) componentsSeparatedByBracketedSequentialNumbers:(NSString*) string {
    if( string == nil ) return nil;

    NSMutableArray* results = [[NSMutableArray alloc] init];

    int commandIndexToFind = 1;
    NSRange searchRange = NSMakeRange(0, string.length);
    while (YES)
    {
        NSString* stringToFind = [NSString stringWithFormat:@"[%d]", commandIndexToFind];
        NSRange range = [string rangeOfString: stringToFind
                                      options: NSLiteralSearch
                                        range: searchRange];
        if ( range.location == NSNotFound ) {
            break;
        }

        NSString* foundString = [string substringWithRange: NSMakeRange(searchRange.location,
                                                                        range.location-searchRange.location)];
        [results addObject: foundString];

        // Move beyond the separator to remainder of string
        NSUInteger rangeEnd = range.location + range.length;
        searchRange = NSMakeRange(rangeEnd, string.length - rangeEnd);

        // Look for next number
        commandIndexToFind++;
    }

    if( searchRange.length > 0 ) {
        // Add remainder of string as the final component of the results
        [results addObject: [string substringWithRange: searchRange]];
    }

    return results;
}

+(NSString*) commandForEntry:(NSString*) entry index:(NSInteger) index {
    NSString* command = entry.stringByTrimmingWhitespace;
    NSInteger returnIndex = [command indexOf:@"\n"];
    if( returnIndex != NSNotFound ) {
        command = [command substringToIndex: returnIndex];
    }
    return [command copy];
}

+(NSString*) outputForEntry:(NSString*) entry {
    NSInteger returnIndex = [entry indexOf:@"\n"];
    if( returnIndex != NSNotFound ) {
        return [entry substringFromIndex: returnIndex+1];
    }
    return @"";
}

-(IFSkeinItem*) decomposeActual:(NSString*) actual {
    return [self decomposeActual: actual ideal: self.composedIdeal];
}

/// For any "test me" style commands, separate out the testing commands into separate "isTestSubItem" child nodes
-(IFSkeinItem*) decomposeActual:(NSString*) actual ideal:(NSString*) ideal {
    if( ![[self class] isTestCommand:_command] ) {
        // This not a "test " command.
        self.actual = actual;
        self.ideal = ideal;
        return self;
    }

    NSArray* actualResults = [IFSkeinItem componentsSeparatedByBracketedSequentialNumbers: actual];
    NSArray* idealResults  = [IFSkeinItem componentsSeparatedByBracketedSequentialNumbers: ideal];
    [self disableUndo];
    if( actualResults.count > 0 ) {
        // Set the first entry text (usually something like "(Testing)\n\n>")
        self.actual = actualResults[0];
        if( idealResults.count > 0 ) {
            self.ideal = idealResults[0];
        }
    }

    if( actualResults.count > 1 ) {
        // Remove but remember the 'real' children of the node ie. skipping over any intermediate test nodes
        NSArray* localChildren = [self.nonTestChildren copy];

        IFSkeinItem* parentItem = self;
        IFSkeinItem* mergedItem = self;

        // Go through remaining entries, inserting test child items as we go
        for( NSInteger index = 1; index < actualResults.count; index++ ) {
            NSString* actualEntry = actualResults[index];
            NSString* actualCommand = [IFSkeinItem commandForEntry: actualEntry index:index];
            NSString* actualOutput  = [IFSkeinItem outputForEntry: actualEntry];
            //NSString* idealCommand = @"";
            NSString* idealOutput = @"";
            if( idealResults.count > index ) {
                NSString* idealEntry = idealResults[index];
                //idealCommand = [IFSkeinItem commandForEntry: idealEntry];
                idealOutput  = [IFSkeinItem outputForEntry: idealEntry];
            }

            IFSkeinItem* newItem = [[IFSkeinItem alloc] initWithSkein: _skein command: actualCommand];
            newItem->_actual = actualOutput;
            newItem->_ideal  = idealOutput;
            newItem->_parent = parentItem;
            newItem->_isTestSubItem = YES;

            mergedItem = [parentItem addChild: newItem];

            // If we have branched off into a new node. We remove any old nodes remaining.
            if( mergedItem == newItem ) {
                for( IFSkeinItem* itemToRemove in [parentItem.children copy] ) {
                    if( itemToRemove != newItem ) {
                        [itemToRemove removeFromParent];
                    }
                }
            }

            parentItem = mergedItem;
        }

        // Remove children from old location and add them in the new location (if location has changed)
        if( mergedItem && localChildren.count > 0 ) {
            if( ((IFSkeinItem*) localChildren[0]).parent != mergedItem ) {
                for( IFSkeinItem* child in localChildren ) {
                    [child removeFromParent];
                }
                
                mergedItem->_children = [localChildren mutableCopy];
                for(IFSkeinItem* item in mergedItem->_children) {
                    item.parent = mergedItem;
                }
                [mergedItem setSkeinRecursively: _skein];
            }
        }

        [self enableUndo];
        return mergedItem;
    }
    [self enableUndo];
    return self;
}

+(BOOL) isTestCommand:(NSString*) command {
    return [command startsWithCaseInsensitive: @"test "];
}

-(IFSkeinItem*) findItemWithNodeId: (unsigned long) skeinNodeId {
    if( self.uniqueId == skeinNodeId ) {
        return self;
    }

    for( IFSkeinItem* child in self.children ) {
        IFSkeinItem* foundItem = [child findItemWithNodeId: skeinNodeId];
        if( foundItem ) {
            return foundItem;
        }
    }
    return nil;
}

-(IFSkeinItem*) decompose {
    return [self decomposeActual:_actual ideal: _ideal];
}

-(NSString*) composedActual {
    // Find the range of items to compose (self -> leafItem)
    IFSkeinItem* leafItem = self;
    int commandTotal = 1;
    while ( leafItem.children.count == 1 ) {
        IFSkeinItem* child = leafItem.children[0];
        if( !child.isTestSubItem ) {
            break;
        }

        leafItem = child;
        commandTotal++;
    }

    // Combine the items
    NSMutableString* combinedActual = [_actual mutableCopy];
    IFSkeinItem* loopItem = self;
    for( int commandIndex = 1; commandIndex < commandTotal; commandIndex++ ) {
        loopItem = loopItem.children[0];
        [combinedActual appendFormat:@"[%d] %@\n%@", commandIndex, loopItem.command, loopItem.actual];
    }
    return combinedActual;
}

-(NSString*) composedIdeal {
    // Find the range of items to compose (self -> leafItem)
    IFSkeinItem* leafItem = self;
    int commandTotal = 1;
    while ( leafItem.children.count == 1 ) {
        IFSkeinItem* child = leafItem.children[0];
        if( !child.isTestSubItem ) {
            break;
        }

        leafItem = child;
        commandTotal++;
    }

    // Combine the items
    NSMutableString* combinedIdeal = [_ideal mutableCopy];
    IFSkeinItem* loopItem = self;
    for( int commandIndex = 1; commandIndex < commandTotal; commandIndex++ ) {
        loopItem = loopItem.children[0];
        [combinedIdeal appendFormat:@"[%d] %@\n%@", commandIndex, loopItem.command, loopItem.ideal];
    }
    return combinedIdeal;
}

#pragma mark - Command Size Cache
-(void) forceCommandSizeChangeRecursively {
    _commandSizeDidChange = YES;
    for( IFSkeinItem* child in _children) {
        [child forceCommandSizeChangeRecursively];
    }
}

#pragma mark - Debugging
-(void) printDEBUG {
    NSLog(@"Item(%lu) '%@'\n", _uniqueId, _command);
    int childCount = 0;
    for(IFSkeinItem* child in _children) {
        NSLog(@"Item(%lu) child #%d:\n", _uniqueId, childCount);
        [child printDEBUG];
        childCount++;
    }
}

#pragma mark - NSPasteboardWriting implementation

- (nullable id)pasteboardPropertyListForType:(nonnull NSPasteboardType)type {
    if ([type isEqualToString:IFSkeinItemPboardType]) {
        return [NSKeyedArchiver archivedDataWithRootObject: self
                                     requiringSecureCoding: YES
                                                     error: NULL];
    }
    return nil;
}

- (nonnull NSArray<NSPasteboardType> *)writableTypesForPasteboard:(nonnull NSPasteboard *)pasteboard {
    if ([pasteboard.name isEqualToString: NSPasteboardNameDrag]) {
        return @[IFSkeinItemPboardType];
    }
    return @[];
}

@end
