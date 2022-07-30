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
        self.options = [[NSMutableArray alloc] init];

        [self.options insertObject: [[IFSyntaxHighlightingOption alloc] init] atIndex: IFSHOptionHeadings];
        [self.options insertObject: [[IFSyntaxHighlightingOption alloc] init] atIndex: IFSHOptionMainText];
        [self.options insertObject: [[IFSyntaxHighlightingOption alloc] init] atIndex: IFSHOptionComments];
        [self.options insertObject: [[IFSyntaxHighlightingOption alloc] init] atIndex: IFSHOptionQuotedText];
        [self.options insertObject: [[IFSyntaxHighlightingOption alloc] init] atIndex: IFSHOptionTextSubstitutions];

        [self resetSettings];
    }
    return self;
}

-(void) resetSettings {
    self.fontFamily = @"Lucida Grande";
    self.fontSize = 12.0f;

    // Syntax highlighting section
    self.enableSyntaxHighlighting = true;

    self.tabWidth = 24.0;

    // Indenting
    self.autoIndentAfterNewline  = true;
    self.autoSpaceTableColumns   = true;

    // Numbering
    self.autoNumberSections      = true;

    // Headings
    IFSyntaxHighlightingOption* option = self.options[IFSHOptionHeadings];
    [option setFontStyle:           IFFontStyleRegular];
    [option setRelativeFontSize:    IFFontSizePlus10];
    [option setUnderline:           true];

    // Main text
    option = self.options[IFSHOptionMainText];
    [option setFontStyle:           IFFontStyleRegular];
    [option setRelativeFontSize:    IFFontSizeNormal];
    [option setUnderline:           false];

    // Comments
    option = self.options[IFSHOptionComments];
    [option setFontStyle:           IFFontStyleRegular];
    [option setRelativeFontSize:    IFFontSizeNormal];
    [option setUnderline:           false];

    // Quoted text
    option = self.options[IFSHOptionQuotedText];
    [option setFontStyle:           IFFontStyleRegular];
    [option setRelativeFontSize:    IFFontSizeNormal];
    [option setUnderline:           false];

    // Text substitutions
    option = self.options[IFSHOptionTextSubstitutions];
    [option setFontStyle:           IFFontStyleRegular];
    [option setRelativeFontSize:    IFFontSizeNormal];
    [option setUnderline:           false];
}


-(void) updateAppPreferencesFromSet {
	IFPreferences* prefs = [IFPreferences sharedPreferences];

    // Text section
    [prefs setSourceFontFamily:     self.fontFamily];
    [prefs setSourceFontSize:       self.fontSize];

    // Syntax highlighting section
    [prefs setEnableSyntaxHighlighting: self.enableSyntaxHighlighting];
    
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption* option = (self.options)[optionIndex];
        [prefs setSourceFontStyle:        option.fontStyle        forOptionType: optionIndex];
        [prefs setSourceUnderline:        option.underline        forOptionType: optionIndex];
        [prefs setSourceRelativeFontSize: option.relativeFontSize forOptionType: optionIndex];
    }

    // Tab width section
    [prefs setTabWidth: self.tabWidth];
    
    // Indenting section
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

    // Syntax highlighting section
    self.enableSyntaxHighlighting = [prefs enableSyntaxHighlighting];
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption * option = (self.options)[optionIndex];
        option.fontStyle        = [prefs sourceFontStyleForOptionType:        optionIndex];
        option.underline        = [prefs sourceUnderlineForOptionType:        optionIndex];
        option.relativeFontSize = [prefs sourceRelativeFontSizeForOptionType: optionIndex];
    }

    // Tab width section
    self.tabWidth = [prefs tabWidth];

    // Indenting section
    self.autoIndentAfterNewline = [prefs indentAfterNewline];
    self.autoSpaceTableColumns = [prefs elasticTabs];
    
    // Numbering section
    self.autoNumberSections = [prefs autoNumberSections];
}

- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type {
    return (self.options)[(NSInteger) type];
}

-(BOOL) isEqualToColor: (NSColor*) color1
                  with: (NSColor*) color2 {
    NSColor *rgb1 = [color1
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgb2 = [color2
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    return rgb1 && rgb2 && [rgb1 isEqual:rgb2];
}

-(BOOL) isEqualToPreferenceSet:(IFEditingPreferencesSet*) set {
    if( ![self.fontFamily isEqualTo: set.fontFamily] ) {
        return NO;
    }
    if( self.fontSize != set.fontSize ) {
        return NO;
    }
    if( self.enableSyntaxHighlighting != set.enableSyntaxHighlighting ) {
        return NO;
    }
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxHighlightingOption * option1 = (self.options)[optionIndex];
        IFSyntaxHighlightingOption * option2 = (set.options)[optionIndex];
        
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
    if (![self isEqualToPreferenceSet:(IFEditingPreferencesSet *)object]) {
        return NO;
    }
    return YES;
}

@end
