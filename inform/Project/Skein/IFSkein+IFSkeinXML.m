//
//  IFSkein+IFSkeinXML.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFUtility.h"

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
        NSLog(@"Error reading XML. \"%@\" (code %lu)\n", error, [error code]);
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
        [newItem setActual: actual];
        [newItem setIdeal: ideal];

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

    while ([itemStack count] > 0) {
        // Pop from the stack
        IFSkeinItem* node = [itemStack lastObject];
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
            if (composedActual != nil) {
                [item addChild: [IFSkein elementWithName: @"result"  value: composedActual preserveWhitespace: YES]];
            }
            if (composedIdeal != nil) {
                [item addChild: [IFSkein elementWithName: @"commentary" value: composedIdeal preserveWhitespace: YES]];
            }

            if (_winningItem == node) {
                [item addChild: [IFSkein elementWithName: @"annotation" value: @"***" preserveWhitespace: YES]];
            }

            [root addChild: item];

            if ([node.children count] > 0) {
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
