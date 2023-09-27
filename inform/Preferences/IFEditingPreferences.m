//
//  IFEditingPreferences.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFEditingPreferences.h"

#import "IFSyntaxManager.h"
#import "IFNaturalHighlighter.h"

#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFEditingPreferences {
    // Text section
    IBOutlet NSTextField* fontFamily;
    IBOutlet NSPopUpButton* selectFont;
    IBOutlet NSSlider* appTextSize;

    // Syntax highlighting section
    IBOutlet NSButton* enableSyntaxHighlighting;
    IBOutlet NSButton* restoreSettingsButton;
    IBOutlet NSTextField* rowHeadings;
    IBOutlet NSTextField* rowMainText;
    IBOutlet NSTextField* rowComments;
    IBOutlet NSTextField* rowQuotedText;
    IBOutlet NSTextField* rowTextSubstitutions;

    IBOutlet NSButton* headingsBold;
    IBOutlet NSButton* mainTextBold;
    IBOutlet NSButton* commentsBold;
    IBOutlet NSButton* quotedTextBold;
    IBOutlet NSButton* textSubstitutionsBold;

    IBOutlet NSButton* headingsItalic;
    IBOutlet NSButton* mainTextItalic;
    IBOutlet NSButton* commentsItalic;
    IBOutlet NSButton* quotedTextItalic;
    IBOutlet NSButton* textSubstitutionsItalic;

    IBOutlet NSButton* headingsUnderline;
    IBOutlet NSButton* mainTextUnderline;
    IBOutlet NSButton* commentsUnderline;
    IBOutlet NSButton* quotedTextUnderline;
    IBOutlet NSButton* textSubstitutionsUnderline;

    IBOutlet NSSlider* headingsFontSize;
    IBOutlet NSSlider* mainTextFontSize;
    IBOutlet NSSlider* commentsFontSize;
    IBOutlet NSSlider* quotedTextFontSize;
    IBOutlet NSSlider* textSubstitutionsFontSize;

    // Tab width section
    IBOutlet NSSlider* tabStopSlider;
    IBOutlet NSTextView* previewView;
    IBOutlet NSTextView* tabStopView;

    // Indenting section
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


- (instancetype) init {
	self = [super initWithNibName: @"EditingPreferences"];
	
	if (self) {
        defaultSet = [[IFEditingPreferencesSet alloc] init];
        currentSet = [[IFEditingPreferencesSet alloc] init];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesEditingDidChangeNotification
												   object: [IFPreferences sharedPreferences]];

		// Create the preview
		NSTextStorage* oldStorage = previewView.textStorage;
		previewStorage = [[NSTextStorage alloc] initWithString: oldStorage.string];
		[IFSyntaxManager registerTextStorage: previewStorage
                                        name: @"Editing Preferences (preview)"
                                        type: IFHighlightTypeInform7
                                intelligence: nil
                                 undoManager: nil];

        [previewView.layoutManager replaceTextStorage: previewStorage];

		// ... and the tab preview
		oldStorage = tabStopView.textStorage;
		tabStopStorage = [[NSTextStorage alloc] initWithString: oldStorage.string];

		[IFSyntaxManager registerTextStorage: tabStopStorage
                                        name: @"Editing Preferences (tab stops)"
                                        type: IFHighlightTypeInform7
                                intelligence: nil
                                 undoManager: nil];

        [tabStopView.layoutManager replaceTextStorage: tabStopStorage];
		tabStopView.textContainerInset = NSMakeSize(0, 2);

		// Register for notifications about view size changes
		[self.preferenceView setPostsFrameChangedNotifications: YES];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(viewWidthChanged:)
													 name: NSViewFrameDidChangeNotification
												   object: self.preferenceView];
		tabStopSlider.maxValue = tabStopSlider.bounds.size.width-12;


		[self reflectCurrentPreferences];
     }

	return self;
}

-(void) dealloc {
    [IFSyntaxManager unregisterTextStorage:previewStorage];
    [IFSyntaxManager unregisterTextStorage:tabStopStorage];
}

#pragma mark - PreferencePane overrides

- (NSString*) preferenceName {
	return @"Editing";
}

- (NSImage*) toolbarImage {
    return [[NSBundle bundleForClass: [self class]] imageForResource: @"App/highlighter"];
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Editing preferences tooltip"];
}

- (CGFloat) maxHeight {
    return CGFLOAT_MAX;
}

- (CGFloat) minHeight {
    return 574.0;
}

#pragma mark - Receiving data from/updating the interface

-(void) updateDependentUIElements {
    bool enabled = (enableSyntaxHighlighting.state == NSControlStateValueOn);
    
    rowHeadings.enabled = enabled;
    rowMainText.enabled = enabled;
    rowComments.enabled = enabled;
    rowQuotedText.enabled = enabled;
    rowTextSubstitutions.enabled = enabled;

    headingsBold.enabled = enabled;
    mainTextBold.enabled = enabled;
    commentsBold.enabled = enabled;
    quotedTextBold.enabled = enabled;
    textSubstitutionsBold.enabled = enabled;

    headingsItalic.enabled = enabled;
    mainTextItalic.enabled = enabled;
    commentsItalic.enabled = enabled;
    quotedTextItalic.enabled = enabled;
    textSubstitutionsItalic.enabled = enabled;

    headingsUnderline.enabled = enabled;
    mainTextUnderline.enabled = enabled;
    commentsUnderline.enabled = enabled;
    quotedTextUnderline.enabled = enabled;
    textSubstitutionsUnderline.enabled = enabled;

    headingsFontSize.enabled = enabled;
    mainTextFontSize.enabled = enabled;
    commentsFontSize.enabled = enabled;
    quotedTextFontSize.enabled = enabled;
    textSubstitutionsFontSize.enabled = enabled;

    // Enable button
    restoreSettingsButton.enabled = ![currentSet isEqualToPreferenceSet:defaultSet];
}

-(void) updateFontStyleFromControlWithSender: (id) sender
                                  optionType: (IFSyntaxHighlightingOptionType) optionType
                                        bold: (NSButton*) boldButton
                                      italic: (NSButton*) italicButton {
    if ((sender == boldButton) || (sender == italicButton)) {
        int result = 0;

        if (boldButton.state == NSControlStateValueOn) {
            result += 2;
        }
        if (italicButton.state == NSControlStateValueOn) {
            result += 1;
        }

        [currentSet optionOfType: optionType].fontStyle = result;
    }
}

- (IBAction) styleSetHasChanged: (id) sender {
    // Update currentSet from preference pane controls
    {
        IFPreferences* prefs = [IFPreferences sharedPreferences];

        if (sender == fontFamily) {
            NSError* error;
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(.*) - (\\d+)$" options:0 error:&error];
            NSString*string = fontFamily.stringValue;
            NSTextCheckingResult *match = [regex firstMatchInString: string
                                                            options: 0
                                                              range: NSMakeRange(0, string.length)];
            if (match) {
                NSRange firstHalfRange = [match rangeAtIndex:1];
                NSRange secondHalfRange = [match rangeAtIndex:2];
                currentSet.fontFamily = [string substringWithRange: firstHalfRange];
                currentSet.fontSize = [string substringWithRange: secondHalfRange].intValue;
             }
        }

        // Text section
        if (sender == appTextSize)                  prefs.appFontSizeMultiplierEnum = appTextSize.intValue;

        // Syntax highlighting section
        if (sender == enableSyntaxHighlighting)     currentSet.enableSyntaxHighlighting = (enableSyntaxHighlighting.state==NSControlStateValueOn);

        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionHeadings          bold: headingsBold          italic: headingsItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionMainText          bold: mainTextBold          italic: mainTextItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionComments          bold: commentsBold          italic: commentsItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionQuotedText        bold: quotedTextBold        italic: quotedTextItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionTextSubstitutions bold: textSubstitutionsBold italic: textSubstitutionsItalic];

        if (sender == headingsUnderline)            [currentSet optionOfType: IFSHOptionHeadings].underline = headingsUnderline.state == NSControlStateValueOn;
        if (sender == mainTextUnderline)            [currentSet optionOfType: IFSHOptionMainText].underline = mainTextUnderline.state == NSControlStateValueOn;
        if (sender == commentsUnderline)            [currentSet optionOfType: IFSHOptionComments].underline = commentsUnderline.state == NSControlStateValueOn;
        if (sender == quotedTextUnderline)          [currentSet optionOfType: IFSHOptionQuotedText].underline = quotedTextUnderline.state == NSControlStateValueOn;
        if (sender == textSubstitutionsUnderline)   [currentSet optionOfType: IFSHOptionTextSubstitutions].underline = textSubstitutionsUnderline.state == NSControlStateValueOn;

        if (sender == headingsFontSize)             [currentSet optionOfType: IFSHOptionHeadings].relativeFontSize = headingsFontSize.intValue;
        if (sender == mainTextFontSize)             [currentSet optionOfType: IFSHOptionMainText].relativeFontSize = mainTextFontSize.intValue;
        if (sender == commentsFontSize)             [currentSet optionOfType: IFSHOptionComments].relativeFontSize = commentsFontSize.intValue;
        if (sender == quotedTextFontSize)           [currentSet optionOfType: IFSHOptionQuotedText].relativeFontSize = quotedTextFontSize.intValue;
        if (sender == textSubstitutionsFontSize)    [currentSet optionOfType: IFSHOptionTextSubstitutions].relativeFontSize = textSubstitutionsFontSize.intValue;

        // Tab width section
        if (sender == tabStopSlider)                currentSet.tabWidth                 = tabStopSlider.floatValue;

        // Indenting section
        if (sender == autoIndentAfterNewline)       currentSet.autoIndentAfterNewline  = (autoIndentAfterNewline.state == NSControlStateValueOn);
        if (sender == autoSpaceTableColumns)        currentSet.autoSpaceTableColumns   = (autoSpaceTableColumns.state  == NSControlStateValueOn);

        // Numbering section
        if (sender == autoNumberSections)           currentSet.autoNumberSections      = (autoNumberSections.state == NSControlStateValueOn);
    }

    // Update dependent UI elements
    if( sender == enableSyntaxHighlighting ) {
        [self updateDependentUIElements];
    }

    // Update application's preferences from currentSet
    [currentSet updateAppPreferencesFromSet];
}

-(void) setFontFamilyUI:(NSString*) fontFamilyName fontSize:(int) points {
    fontFamily.stringValue = [NSString stringWithFormat: @"%@ - %d", fontFamilyName, points];
}

-(void) setControlsFromFontStyle: (int) fontStyle
                            bold: (NSButton*) bold
                          italic: (NSButton*) italic {
    bold.state   = ((fontStyle & 2) != 0) ? NSControlStateValueOn : NSControlStateValueOff;
    italic.state = ((fontStyle & 1) != 0) ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void) reflectCurrentPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
	
    // Update currentSet based on application's current preferences
    [currentSet updateSetFromAppPreferences];

    // Update preference pane UI elements from currentSet
    
    // Text section
    [self setFontFamilyUI: currentSet.fontFamily fontSize: currentSet.fontSize];
    appTextSize.intValue = prefs.appFontSizeMultiplierEnum;

    // Syntax highlighting section
	enableSyntaxHighlighting.state = currentSet.enableSyntaxHighlighting ? NSControlStateValueOn : NSControlStateValueOff;

    IFSyntaxHighlightingOption* option = (currentSet.options)[IFSHOptionHeadings];
    [self setControlsFromFontStyle: option.fontStyle bold: headingsBold italic: headingsItalic];
    headingsUnderline.state = option.underline ? NSControlStateValueOn : NSControlStateValueOff;
    headingsFontSize.intValue = option.relativeFontSize;

    option = (currentSet.options)[IFSHOptionMainText];
    [self setControlsFromFontStyle: option.fontStyle bold: mainTextBold italic: mainTextItalic];
    mainTextUnderline.state = option.underline ? NSControlStateValueOn : NSControlStateValueOff;
    mainTextFontSize.intValue = option.relativeFontSize;

    option = (currentSet.options)[IFSHOptionComments];
    [self setControlsFromFontStyle: option.fontStyle bold: commentsBold italic: commentsItalic];
    commentsUnderline.state = option.underline ? NSControlStateValueOn : NSControlStateValueOff;
    commentsFontSize.intValue = option.relativeFontSize;

    option = (currentSet.options)[IFSHOptionQuotedText];
    [self setControlsFromFontStyle: option.fontStyle bold: quotedTextBold italic: quotedTextItalic];
    quotedTextUnderline.state = option.underline ? NSControlStateValueOn : NSControlStateValueOff;
    quotedTextFontSize.intValue = option.relativeFontSize;

    option = (currentSet.options)[IFSHOptionTextSubstitutions];
    [self setControlsFromFontStyle: option.fontStyle bold: textSubstitutionsBold italic: textSubstitutionsItalic];
    textSubstitutionsUnderline.state = option.underline ? NSControlStateValueOn : NSControlStateValueOff;
    textSubstitutionsFontSize.intValue = option.relativeFontSize;

    // Tab width section
	tabStopSlider.maxValue = tabStopSlider.bounds.size.width-12;
	tabStopSlider.floatValue = prefs.tabWidth;

    // Indenting section
    autoIndentAfterNewline.state = currentSet.autoIndentAfterNewline ? NSControlStateValueOn : NSControlStateValueOff;
    autoSpaceTableColumns.state = currentSet.autoSpaceTableColumns  ? NSControlStateValueOn : NSControlStateValueOff;

    // Numbering section
    autoNumberSections.state = currentSet.autoNumberSections     ? NSControlStateValueOn : NSControlStateValueOff;

    // Update dependent elements
    [self updateDependentUIElements];
    
    // Update paper colour on preview
    previewView.backgroundColor = prefs.sourcePaper.colour;

    // Rehighlight the preview views
	[IFSyntaxManager preferencesChanged: tabStopStorage];
	[IFSyntaxManager highlightAll: tabStopStorage
                  forceUpdateTabs: true];
	[IFSyntaxManager preferencesChanged: previewStorage];
	[IFSyntaxManager highlightAll: previewStorage
                  forceUpdateTabs: true];
}

- (void) viewWidthChanged: (NSNotification*) not {
	// Update the maximum value of the tab slider
	tabStopSlider.maxValue = tabStopSlider.bounds.size.width-12;
}

- (IBAction) showFontPicker:(id) sender {
    NSFontPanel* fontPanel = [NSFontPanel sharedFontPanel];
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    fontManager.action = @selector(selectFont:);
    fontManager.target = self;
    [fontManager orderFrontFontPanel: fontPanel];

    NSFont* font = [NSFont fontWithName:currentSet.fontFamily size:currentSet.fontSize];
    [fontManager setSelectedFont:font isMultiple:NO];
}

-(void) selectFont:(id) sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont* originalFont = [NSFont boldSystemFontOfSize:12];
    NSFont* selectedFont = [fontManager convertFont:originalFont];

    [self setFontFamilyUI: selectedFont.familyName fontSize: selectedFont.pointSize];
    [self styleSetHasChanged: fontFamily];
}

- (IBAction) restoreDefaultSettings:(id) sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Restore"]];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Cancel"]];
    alert.messageText = [IFUtility localizedString: @"Reset the editing preferences?"];
    alert.informativeText = [IFUtility localizedString: @"This action cannot be undone."];
    alert.alertStyle = NSAlertStyleWarning;

    if ([alert runModal] == NSAlertFirstButtonReturn ) {
        [currentSet resetSettings];
        
        [[IFPreferences sharedPreferences] startBatchEditing];
        [currentSet updateAppPreferencesFromSet];
        [[IFPreferences sharedPreferences] endBatchEditing];

        [self reflectCurrentPreferences];
    }
}

@end
