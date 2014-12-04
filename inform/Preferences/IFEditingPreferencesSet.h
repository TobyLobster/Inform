//
//  IFEditingPreferencesSet.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

@interface IFSyntaxHighlightingOption : NSObject {
@public
    NSColor*            _colour;
    IFFontStyle         _fontStyle;
    bool                _underline;
    IFRelativeFontSize  _relativeFontSize;
}

@property (strong) NSColor*   colour;
@property IFFontStyle         fontStyle;
@property bool                underline;
@property IFRelativeFontSize  relativeFontSize;

-(id) init;

@end

@interface IFEditingPreferencesSet : NSObject {
@public
    // Text section
    NSString*       _fontFamily;
    int             _fontSize;
    NSColor*        _sourcePaperColor;
    NSColor*        _extensionPaperColor;

    // Syntax highlighting section
    bool            _enableSyntaxHighlighting;
    NSMutableArray* _options;            // Array of IFSyntaxHighlightingOptions
    
    // Tab width section
    float           _tabWidth;

    // Indenting
    bool            _indentWrappedLines;
    bool            _autoIndentAfterNewline;
    bool            _autoSpaceTableColumns;
    
    // Numbering
    bool            _autoNumberSections;
}

@property (strong) NSString*        fontFamily;
@property int                       fontSize;
@property (strong) NSColor*         sourcePaperColor;
@property (strong) NSColor*         extensionPaperColor;
@property bool                      enableSyntaxHighlighting;
@property (strong) NSMutableArray*  options;            // Array of IFSyntaxHighlightingOptions
@property float                     tabWidth;
@property bool                      indentWrappedLines;
@property bool                      autoIndentAfterNewline;
@property bool                      autoSpaceTableColumns;
@property bool                      autoNumberSections;

- (id) init;
- (void) updateAppPreferencesFromSet;
- (void) updateSetFromAppPreferences;
- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
-(BOOL) isEqualToEditingPreferenceSet:(IFEditingPreferencesSet*) set;
-(BOOL) isEqual:(id)object;

@end
