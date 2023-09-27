//
//  IFSyntaxManager.m
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import "IFPreferences.h"
#import "IFSyntaxManager.h"
#import "IFProjectTypes.h"

@implementation IFSyntaxManager

static NSMutableDictionary<NSValue*,IFSyntaxData*>* storages = nil;

#pragma mark - Initialisation
+(void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        storages = [[NSMutableDictionary alloc] init];
    });
}

+(void) dealloc {
    [super dealloc];
}


///
/// Internal
///
+(IFSyntaxData*) dataForStorage: (NSTextStorage*) storage {
    return storages[[NSValue valueWithNonretainedObject:storage]];
}

//
// Registration
//
+(void) registerTextStorage: (NSTextStorage*) storage
                       name: (NSString*) name
                       type: (IFHighlightType) type
               intelligence: (id<IFSyntaxIntelligence>) intelligence
                undoManager: (NSUndoManager*) undoManager {
    IFSyntaxData* data = [[IFSyntaxData alloc] initWithStorage: storage
                                                           name: name
                                                           type: type
                                                   intelligence: intelligence
                                                    undoManager: undoManager];
    //NSLog(@"*** Register %@ with storage %d", name, (int) storage);
    storages[[NSValue valueWithNonretainedObject: storage]] = data;
}

+(void) registerTextStorage: (NSTextStorage*) storage
                   filename: (NSString*) filename
               intelligence: (id<IFSyntaxIntelligence>) intelligence
                undoManager: (NSUndoManager*) undoManager {
    [IFSyntaxManager registerTextStorage: storage
                                    name: filename
                                    type: [IFProjectTypes highlighterTypeForFilename: filename]
                            intelligence: intelligence
                             undoManager: undoManager];
}

+(void) unregisterTextStorage: (NSTextStorage*) storage {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage:storage];
    if( data ) {
        // NSLog(@"*** Unregister %@ with storage %d", [data name], (int) storage);
        [storages removeObjectForKey: [NSValue valueWithNonretainedObject: storage]];
    } else {
        // NSLog(false, @"removing storage %@ that's not registered", storage);
    }
}

+(bool) isRegistered: (NSTextStorage*) storage {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return data != nil;
}

//
// Syntax highlighting
//
+(void) highlightAll: (NSTextStorage*) storage
     forceUpdateTabs: (bool) forceUpdateTabs {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    [data highlightAllForceUpdateTabs: forceUpdateTabs];
}

+(void) preferencesChanged: (NSTextStorage*) storage {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    [data preferencesChanged: nil];
}

//
// Restricted Storage
//
+(void) restrictStorage: (NSTextStorage*) storage
                  range: (NSRange) range
            forTextView: (NSTextView*) view {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    [data restrictToRange: range
              forTextView: view];
}

+(void) removeRestriction: (NSTextStorage*) storage
              forTextView: (NSTextView*) view {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    [data removeRestrictionForTextView: view];
}

+(bool) isRestricted: (NSTextStorage*) storage
         forTextView: (NSTextView*) view {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return [data isRestrictedForTextView: view];
}

+(NSRange) restrictedRange: (NSTextStorage*) storage
               forTextView: (NSTextView*) view {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return [data restrictedRangeForTextView: view];
}

+(NSTextStorage*) restrictedTextStorage: (NSTextStorage*) storage
                            forTextView: (NSTextView*) view {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return [data restrictedTextStorageForTextView: view];
}

//
// Renumbering sections
//
+(NSString*) textForLineWithStorage: (NSTextStorage*) storage
                         lineNumber: (int) line {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return [data textForLine: line];
}

+(void) replaceLineWithStorage: (NSTextStorage*) storage
                    lineNumber: (int) lineNumber
                      withLine: (NSString*) line {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage: storage];
    return [data replaceLine: lineNumber
                    withLine: line];
}


//
// Intelligence
//
+(void) setIntelligenceForStorage: (NSTextStorage*) storage
                     intelligence: (id<IFSyntaxIntelligence>) intelligence {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage:storage];
    data.intelligence = intelligence;
}

+(IFIntelFile*) intelligenceDataForStorage: (NSTextStorage*) storage {
    IFSyntaxData* data = [IFSyntaxManager dataForStorage:storage];
    return data.intelligenceData;
}

@end
