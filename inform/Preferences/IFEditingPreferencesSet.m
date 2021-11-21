//
//  IFEditingPreferencesSet.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFEditingPreferences.h"

#import "IFSyntaxManager.h"
#import "IFNaturalHighlighter.h"

#import "IFPreferences.h"

@implementation IFSyntaxHighlightingOption

-(instancetype) init {
    self = [super init];
    if( self ) {
        self.colour           = [NSColor whiteColor];
        self.fontStyle        = 0;
        self.underline        = false;
        self.relativeFontSize = IFFontSizeNormal;
    }
    return self;
}

@end

@implementation IFEditingPreferencesSet

-(instancetype) init {
    self = [super init];
    if( self ) {
        self.fontFamily = @"Lucida Grande";
        self.fontSize = 12.0f;
        self.sourcePaperColor    = [NSColor whiteColor];
        self.extensionPaperColor = [NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 0.9 alpha: 1.0];

        self.options = [[NSMutableArray alloc] init];

        // Syntax highlighting section
        self.enableSyntaxHighlighting = true;
        IFSyntaxHighlightingOption* option = [[IFSyntaxHighlightingOption alloc] init];

        // Headings
        [option setColour:              [NSColor blackColor]];
        [option setFontStyle:           IFFontStyleBold];
        [option setRelativeFontSize:    IFFontSizePlus10];
        [option setUnderline:           false];
        [self.options insertObject: option atIndex: IFSHOptionHeadings];

        option = [[IFSyntaxHighlightingOption alloc] init];
        
        // Main text
        [option setColour:              [NSColor blackColor]];
        [option setFontStyle:           IFFontStyleRegular];
        [option setRelativeFontSize:    IFFontSizeNormal];
        [option setUnderline:           false];
        [self.options insertObject: option atIndex: IFSHOptionMainText];

        option = [[IFSyntaxHighlightingOption alloc] init];

        // Comments
        [option setColour:              [NSColor colorWithDeviceRed: 0.14 green: 0.43 blue: 0.14 alpha: 1.0]];
        [option setFontStyle:           IFFontStyleBold];
        [option setRelativeFontSize:    IFFontSizeMinus20];
        [option setUnderline:           false];
        [self.options insertObject: option atIndex: IFSHOptionComments];

        option = [[IFSyntaxHighlightingOption alloc] init];

        // Quoted text
        [option setColour:              [NSColor colorWithDeviceRed: 0.0 green: 0.3 blue: 0.6 alpha: 1.0]];
        [option setFontStyle:           IFFontStyleBold];
        [option setRelativeFontSize:    IFFontSizeNormal];
        [option setUnderline:           false];
        [self.options insertObject: option atIndex: IFSHOptionQuotedText];

        option = [[IFSyntaxHighlightingOption alloc] init];

        // Text substitutions
        [option setColour:              [NSColor colorWithDeviceRed: 0.3 green: 0.3 blue: 1.0 alpha: 1.0]];
        [option setFontStyle:           IFFontStyleRegular];
        [option setRelativeFontSize:    IFFontSizeNormal];
        [option setUnderline:           false];
        [self.options insertObject: option atIndex: IFSHOptionTextSubstitutions];


        self.tabWidth = 24.0f;

        // Indenting
        self.indentWrappedLines      = true;
        self.autoIndentAfterNewline  = true;
        self.autoSpaceTableColumns   = true;

        // Numbering
        self.autoNumberSections      = true;
    }
    return self;
}


-(void) updateAppPreferencesFromSet {
	IFPreferences* prefs = [IFPreferences sharedPreferences];

    // Text section
    [prefs setSourceFontFamily:     self.fontFamily];
    [prefs setSourceFontSize:       self.fontSize];
    [prefs setSourcePaperColour:    self.sourcePaperColor];
    [prefs setExtensionPaperColour: self.extensionPaperColor];

    // Syntax highlighting section
    [prefs setEnableSyntaxHighlighting: self.enableSyntaxHighlighting];
    
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption* option = (self.options)[optionIndex];
        [prefs setSourceColour:           option.colour           forOptionType: optionIndex];
        [prefs setSourceFontStyle:        option.fontStyle        forOptionType: optionIndex];
        [prefs setSourceUnderline:        option.underline        forOptionType: optionIndex];
        [prefs setSourceRelativeFontSize: option.relativeFontSize forOptionType: optionIndex];
    }

    // Tab width section
    [prefs setTabWidth: self.tabWidth];
    
    // Indenting section
    [prefs setIndentWrappedLines: self.indentWrappedLines];
    [prefs setIndentAfterNewline: self.autoIndentAfterNewline];
    [prefs setElasticTabs:        self.autoSpaceTableColumns];

    // Numbering section
    [prefs setAutoNumberSections: self.autoNumberSections];
}

-(void) updateSetFromAppPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
    
    // Text section
    self.fontFamily          = [prefs sourceFontFamily];
    self.fontSize            = [prefs sourceFontSize];
    self.sourcePaperColor    = [prefs sourcePaperColour];
    self.extensionPaperColor = [prefs extensionPaperColour];

    // Syntax highlighting section
    self.enableSyntaxHighlighting = [prefs enableSyntaxHighlighting];
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption * option = (self.options)[optionIndex];
        option.colour           = [prefs sourceColourForOptionType:           optionIndex];
        option.fontStyle        = [prefs sourceFontStyleForOptionType:        optionIndex];
        option.underline        = [prefs sourceUnderlineForOptionType:        optionIndex];
        option.relativeFontSize = [prefs sourceRelativeFontSizeForOptionType: optionIndex];
    }

    // Tab width section
    self.tabWidth = [prefs tabWidth];

    // Indenting section
    self.indentWrappedLines = [prefs indentWrappedLines];
    self.autoIndentAfterNewline = [prefs indentAfterNewline];
    self.autoSpaceTableColumns = [prefs elasticTabs];
    
    // Numbering section
    self.autoNumberSections = [prefs autoNumberSections];
}

- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type {
    return (IFSyntaxHighlightingOption*) (self.options)[(int) type];
}

-(BOOL) isEqualToColor: (NSColor*) color1
                  with: (NSColor*) color2 {
    NSColor *rgb1 = [color1
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgb2 = [color2
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    return rgb1 && rgb2 && [rgb1 isEqual:rgb2];
}

-(BOOL) isEqualToEditingPreferenceSet:(IFEditingPreferencesSet*) set {
    if( ![self.fontFamily isEqualTo: set.fontFamily] ) {
        return NO;
    }
    if( self.fontSize != set.fontSize ) {
        return NO;
    }
    if( ![self isEqualToColor: self.sourcePaperColor
                         with: set.sourcePaperColor] ) {
        return NO;
    }
    if( ![self isEqualToColor: self.extensionPaperColor
                         with: set.extensionPaperColor] ) {
        return NO;
    }
    if( self.enableSyntaxHighlighting != set.enableSyntaxHighlighting ) {
        return NO;
    }
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption * option1 = (self.options)[optionIndex];
        IFSyntaxHighlightingOption * option2 = (set.options)[optionIndex];
        
        if( ![self isEqualToColor: option1.colour
                             with: option2.colour] ) {
            return NO;
        }
        if( option1.fontStyle != option2.fontStyle ) {
            return NO;
        }
        if( option1.underline != option2.underline ) {
            return NO;
        }
        if( option1.relativeFontSize != option2.relativeFontSize ) {
            return NO;
        }
    }
    if( self.tabWidth != set.tabWidth ) {
        return NO;
    }
    if( self.indentWrappedLines != set.indentWrappedLines ) {
        return NO;
    }
    if( self.autoIndentAfterNewline != set.autoIndentAfterNewline ) {
        return NO;
    }
    if( self.autoSpaceTableColumns != set.autoSpaceTableColumns ) {
        return NO;
    }
    if( self.autoNumberSections != set.autoNumberSections ) {
        return NO;
    }

    return YES;
}

-(BOOL) isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[IFEditingPreferencesSet class]]) {
        return NO;
    }
    return [self isEqualToEditingPreferenceSet:(IFEditingPreferencesSet *)object];
}

@end
