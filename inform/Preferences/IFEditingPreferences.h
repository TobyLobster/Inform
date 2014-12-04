//
//  IFEditingPreferences.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFEditingPreferencesSet.h"
#import "IFPreferencePane.h"
#import "IFPreferences.h"

#import "IFSyntaxTypes.h"

//
// Preference pane that allows the user to select the styles she wants to see
//
@interface IFEditingPreferences : IFPreferencePane {
    // Text section
	IBOutlet NSPopUpButton* fontFamily;
    IBOutlet NSTextField* fontSize;
    IBOutlet NSColorWell* sourceColour;
    IBOutlet NSColorWell* extensionColor;
    
    // Syntax highlighting section
	IBOutlet NSButton* enableSyntaxHighlighting;
	IBOutlet NSButton* restoreSettingsButton;
    IBOutlet NSTextField* rowHeadings;
    IBOutlet NSTextField* rowMainText;
    IBOutlet NSTextField* rowComments;
    IBOutlet NSTextField* rowQuotedText;
    IBOutlet NSTextField* rowTextSubstitutions;
    IBOutlet NSTextField* columnColour;
    IBOutlet NSTextField* columnFontStyle;
    IBOutlet NSTextField* columnUnderline;
    IBOutlet NSTextField* columnFontSize;
    IBOutlet NSColorWell* headingsColor;
    IBOutlet NSColorWell* mainTextColor;
    IBOutlet NSColorWell* commentsColor;
    IBOutlet NSColorWell* quotedTextColor;
    IBOutlet NSColorWell* textSubstitutionsColor;
    IBOutlet NSPopUpButton* headingsFontStyle;
    IBOutlet NSPopUpButton* mainTextFontStyle;
    IBOutlet NSPopUpButton* commentsFontStyle;
    IBOutlet NSPopUpButton* quotedTextFontStyle;
    IBOutlet NSPopUpButton* textSubstitutionsFontStyle;
    IBOutlet NSButton* headingsUnderline;
    IBOutlet NSButton* mainTextUnderline;
    IBOutlet NSButton* commentsUnderline;
    IBOutlet NSButton* quotedTextUnderline;
    IBOutlet NSButton* textSubstitutionsUnderline;
    IBOutlet NSPopUpButton* headingsFontSize;
    IBOutlet NSPopUpButton* mainTextFontSize;
    IBOutlet NSPopUpButton* commentsFontSize;
    IBOutlet NSPopUpButton* quotedTextFontSize;
    IBOutlet NSPopUpButton* textSubstitutionsFontSize;

    // Tab width section
	IBOutlet NSSlider* tabStopSlider;
	IBOutlet NSTextView* previewView;
	IBOutlet NSTextView* tabStopView;

    // Indenting section
    IBOutlet NSButton* indentWrappedLines;
    IBOutlet NSButton* autoIndentAfterNewline;
    IBOutlet NSButton* autoSpaceTableColumns;

    // Numbering section
    IBOutlet NSButton* autoNumberSections;

    // Text storage for previews
	NSTextStorage* previewStorage;
	NSTextStorage* tabStopStorage;

    IFEditingPreferencesSet* defaultSet;
    IFEditingPreferencesSet* currentSet;
}

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (id) sender;
- (void) reflectCurrentPreferences;
- (IBAction) restoreDefaultSettings: (id) sender;

@end
