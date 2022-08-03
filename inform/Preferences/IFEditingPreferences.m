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
		NSTextStorage* oldStorage = [previewView textStorage];
		previewStorage = [[NSTextStorage alloc] initWithString: [oldStorage string]];
		[IFSyntaxManager registerTextStorage: previewStorage
                                        name: @"Editing Preferences (preview)"
                                        type: IFHighlightTypeInform7
                                intelligence: nil
                                 undoManager: nil];

        [previewView.layoutManager replaceTextStorage: previewStorage];

		// ... and the tab preview
		oldStorage = [tabStopView textStorage];
		tabStopStorage = [[NSTextStorage alloc] initWithString: [oldStorage string]];

		[IFSyntaxManager registerTextStorage: tabStopStorage
                                        name: @"Editing Preferences (tab stops)"
                                        type: IFHighlightTypeInform7
                                intelligence: nil
                                 undoManager: nil];

        [tabStopView.layoutManager replaceTextStorage: tabStopStorage];
		[tabStopView setTextContainerInset: NSMakeSize(0, 2)];

		// Register for notifications about view size changes
		[self.preferenceView setPostsFrameChangedNotifications: YES];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(viewWidthChanged:)
													 name: NSViewFrameDidChangeNotification
												   object: self.preferenceView];
		[tabStopSlider setMaxValue: [tabStopSlider bounds].size.width-12];


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
    return [[NSBundle bundleForClass: [self class]] imageForResource: @"App/highlighter2"];
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Editing preferences tooltip"];
}

#pragma mark - Receiving data from/updating the interface

-(void) updateDependentUIElements {
    bool enabled = ([enableSyntaxHighlighting state] == NSControlStateValueOn);
    
    [rowHeadings                setEnabled: enabled];
    [rowMainText                setEnabled: enabled];
    [rowComments                setEnabled: enabled];
    [rowQuotedText              setEnabled: enabled];
    [rowTextSubstitutions       setEnabled: enabled];

    [headingsBold               setEnabled: enabled];
    [mainTextBold               setEnabled: enabled];
    [commentsBold               setEnabled: enabled];
    [quotedTextBold             setEnabled: enabled];
    [textSubstitutionsBold      setEnabled: enabled];

    [headingsItalic             setEnabled: enabled];
    [mainTextItalic             setEnabled: enabled];
    [commentsItalic             setEnabled: enabled];
    [quotedTextItalic           setEnabled: enabled];
    [textSubstitutionsItalic    setEnabled: enabled];

    [headingsUnderline          setEnabled: enabled];
    [mainTextUnderline          setEnabled: enabled];
    [commentsUnderline          setEnabled: enabled];
    [quotedTextUnderline        setEnabled: enabled];
    [textSubstitutionsUnderline setEnabled: enabled];

    [headingsFontSize           setEnabled: enabled];
    [mainTextFontSize           setEnabled: enabled];
    [commentsFontSize           setEnabled: enabled];
    [quotedTextFontSize         setEnabled: enabled];
    [textSubstitutionsFontSize  setEnabled: enabled];

    // Enable button
    [restoreSettingsButton setEnabled: ![currentSet isEqualToPreferenceSet:defaultSet]];
}

-(void) updateFontStyleFromControlWithSender: (id) sender
                                  optionType: (IFSyntaxHighlightingOptionType) optionType
                                        bold: (NSButton*) boldButton
                                      italic: (NSButton*) italicButton {
    if ((sender == boldButton) || (sender == italicButton)) {
        int result = 0;

        if ([boldButton state] == NSControlStateValueOn) {
            result += 2;
        }
        if ([italicButton state] == NSControlStateValueOn) {
            result += 1;
        }

        [[currentSet optionOfType: optionType] setFontStyle: result];
    }
}

- (IBAction) styleSetHasChanged: (id) sender {
    // Update currentSet from preference pane controls
    {
        IFPreferences* prefs = [IFPreferences sharedPreferences];

        if (sender == fontFamily) {
            NSError* error;
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(.*) - (\\d+)$" options:0 error:&error];
            NSString*string = [fontFamily stringValue];
            NSTextCheckingResult *match = [regex firstMatchInString: string
                                                            options: 0
                                                              range: NSMakeRange(0, [string length])];
            if (match) {
                NSRange firstHalfRange = [match rangeAtIndex:1];
                NSRange secondHalfRange = [match rangeAtIndex:2];
                currentSet.fontFamily = [string substringWithRange: firstHalfRange];
                currentSet.fontSize = [[string substringWithRange: secondHalfRange] intValue];
             }
        }

        // Text section
        if (sender == appTextSize)                  [prefs setAppFontSizeMultiplierEnum: [appTextSize intValue]];

        // Syntax highlighting section
        if (sender == enableSyntaxHighlighting)     currentSet.enableSyntaxHighlighting = ([enableSyntaxHighlighting state]==NSControlStateValueOn);

        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionHeadings          bold: headingsBold          italic: headingsItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionMainText          bold: mainTextBold          italic: mainTextItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionComments          bold: commentsBold          italic: commentsItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionQuotedText        bold: quotedTextBold        italic: quotedTextItalic];
        [self updateFontStyleFromControlWithSender: sender optionType: IFSHOptionTextSubstitutions bold: textSubstitutionsBold italic: textSubstitutionsItalic];

        if (sender == headingsUnderline)            [[currentSet optionOfType: IFSHOptionHeadings]          setUnderline:  [headingsUnderline state] == NSControlStateValueOn];
        if (sender == mainTextUnderline)            [[currentSet optionOfType: IFSHOptionMainText]          setUnderline:  [mainTextUnderline state] == NSControlStateValueOn];
        if (sender == commentsUnderline)            [[currentSet optionOfType: IFSHOptionComments]          setUnderline:  [commentsUnderline state] == NSControlStateValueOn];
        if (sender == quotedTextUnderline)          [[currentSet optionOfType: IFSHOptionQuotedText]        setUnderline:  [quotedTextUnderline state] == NSControlStateValueOn];
        if (sender == textSubstitutionsUnderline)   [[currentSet optionOfType: IFSHOptionTextSubstitutions] setUnderline:  [textSubstitutionsUnderline state] == NSControlStateValueOn];

        if (sender == headingsFontSize)             [[currentSet optionOfType: IFSHOptionHeadings]          setRelativeFontSize:  [headingsFontSize intValue]];
        if (sender == mainTextFontSize)             [[currentSet optionOfType: IFSHOptionMainText]          setRelativeFontSize:  [mainTextFontSize intValue]];
        if (sender == commentsFontSize)             [[currentSet optionOfType: IFSHOptionComments]          setRelativeFontSize:  [commentsFontSize intValue]];
        if (sender == quotedTextFontSize)           [[currentSet optionOfType: IFSHOptionQuotedText]        setRelativeFontSize:  [quotedTextFontSize intValue]];
        if (sender == textSubstitutionsFontSize)    [[currentSet optionOfType: IFSHOptionTextSubstitutions] setRelativeFontSize:  [textSubstitutionsFontSize intValue]];

        // Tab width section
        if (sender == tabStopSlider)                currentSet.tabWidth                 = [tabStopSlider floatValue];

        // Indenting section
        if (sender == autoIndentAfterNewline)       currentSet.autoIndentAfterNewline  = ([autoIndentAfterNewline state] == NSControlStateValueOn);
        if (sender == autoSpaceTableColumns)        currentSet.autoSpaceTableColumns   = ([autoSpaceTableColumns state]  == NSControlStateValueOn);

        // Numbering section
        if (sender == autoNumberSections)           currentSet.autoNumberSections      = ([autoNumberSections state] == NSControlStateValueOn);
    }

    // Update dependent UI elements
    if( sender == enableSyntaxHighlighting ) {
        [self updateDependentUIElements];
    }

    // Update application's preferences from currentSet
    [currentSet updateAppPreferencesFromSet];
}

-(void) setFontFamilyUI:(NSString*) fontFamilyName fontSize:(int) points {
    [fontFamily setStringValue: [NSString stringWithFormat: @"%@ - %d", fontFamilyName, points]];
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
    [appTextSize setIntValue: [prefs appFontSizeMultiplierEnum]];

    // Syntax highlighting section
	[enableSyntaxHighlighting setState: currentSet.enableSyntaxHighlighting ? NSControlStateValueOn : NSControlStateValueOff];

    IFSyntaxHighlightingOption* option = (currentSet.options)[IFSHOptionHeadings];
    [self setControlsFromFontStyle: option.fontStyle bold: headingsBold italic: headingsItalic];
    [headingsUnderline  setState:    option.underline ? NSControlStateValueOn : NSControlStateValueOff];
    [headingsFontSize   setIntValue: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionMainText];
    [self setControlsFromFontStyle: option.fontStyle bold: mainTextBold italic: mainTextItalic];
    [mainTextUnderline  setState:    option.underline ? NSControlStateValueOn : NSControlStateValueOff];
    [mainTextFontSize   setIntValue: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionComments];
    [self setControlsFromFontStyle: option.fontStyle bold: commentsBold italic: commentsItalic];
    [commentsUnderline  setState:    option.underline ? NSControlStateValueOn : NSControlStateValueOff];
    [commentsFontSize   setIntValue: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionQuotedText];
    [self setControlsFromFontStyle: option.fontStyle bold: quotedTextBold italic: quotedTextItalic];
    [quotedTextUnderline    setState:    option.underline ? NSControlStateValueOn : NSControlStateValueOff];
    [quotedTextFontSize     setIntValue: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionTextSubstitutions];
    [self setControlsFromFontStyle: option.fontStyle bold: textSubstitutionsBold italic: textSubstitutionsItalic];
    [textSubstitutionsUnderline setState:    option.underline ? NSControlStateValueOn : NSControlStateValueOff];
    [textSubstitutionsFontSize  setIntValue: option.relativeFontSize];

    // Tab width section
	[tabStopSlider  setMaxValue: [tabStopSlider bounds].size.width-12];
	[tabStopSlider  setFloatValue: [prefs tabWidth]];

    // Indenting section
    [autoIndentAfterNewline setState: currentSet.autoIndentAfterNewline ? NSControlStateValueOn : NSControlStateValueOff];
    [autoSpaceTableColumns  setState: currentSet.autoSpaceTableColumns  ? NSControlStateValueOn : NSControlStateValueOff];

    // Numbering section
    [autoNumberSections     setState: currentSet.autoNumberSections     ? NSControlStateValueOn : NSControlStateValueOff];

    // Update dependent elements
    [self updateDependentUIElements];
    
    // Update paper colour on preview
    [previewView setBackgroundColor: [prefs getSourcePaper].colour];

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
	[tabStopSlider setMaxValue: [tabStopSlider bounds].size.width-12];
}

- (IBAction) showFontPicker:(id) sender {
    NSFontPanel* fontPanel = [NSFontPanel sharedFontPanel];
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setAction: @selector(selectFont:)];
    [fontManager setTarget: self];
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
    [alert setMessageText:     [IFUtility localizedString: @"Reset the editing preferences?"]];
    [alert setInformativeText: [IFUtility localizedString: @"This action cannot be undone."]];
    [alert setAlertStyle:NSAlertStyleWarning];

    if ([alert runModal] == NSAlertFirstButtonReturn ) {
        [currentSet resetSettings];
        
        [[IFPreferences sharedPreferences] startBatchEditing];
        [currentSet updateAppPreferencesFromSet];
        [[IFPreferences sharedPreferences] endBatchEditing];

        [self reflectCurrentPreferences];
    }
}

@end
