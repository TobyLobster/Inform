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
#import "IFImageCache.h"
#import "IFUtility.h"

@implementation IFEditingPreferences {
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

        // Populate font family drop down with fonts
        [fontFamily removeAllItems];
        for( NSString* name in [[NSFontManager sharedFontManager] availableFontFamilies] ) {
            [fontFamily addItemWithTitle: name];
        }

		[self reflectCurrentPreferences];
     }

	return self;
}

-(void) dealloc {

    [IFSyntaxManager unregisterTextStorage:previewStorage];
    [IFSyntaxManager unregisterTextStorage:tabStopStorage];


    
}

// = PreferencePane overrides =

- (NSString*) preferenceName {
	return @"Editing";
}

- (NSImage*) toolbarImage {
	return [NSImage imageNamed: NSImageNameMultipleDocuments];
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Editing preferences tooltip"];
}

// = Receiving data from/updating the interface =

-(void) updateDependentUIElements {
    bool enabled = ([enableSyntaxHighlighting state] == NSOnState);
    
    [rowHeadings                setEnabled: enabled];
    [rowMainText                setEnabled: enabled];
    [rowComments                setEnabled: enabled];
    [rowQuotedText              setEnabled: enabled];
    [rowTextSubstitutions       setEnabled: enabled];
    [columnColour               setEnabled: enabled];
    [columnFontStyle            setEnabled: enabled];
    [columnUnderline            setEnabled: enabled];
    [columnFontSize             setEnabled: enabled];
    
    [headingsColor              setEnabled: enabled];
    [mainTextColor              setEnabled: enabled];
    [commentsColor              setEnabled: enabled];
    [quotedTextColor            setEnabled: enabled];
    [textSubstitutionsColor     setEnabled: enabled];
    [headingsFontStyle          setEnabled: enabled];
    [mainTextFontStyle          setEnabled: enabled];
    [commentsFontStyle          setEnabled: enabled];
    [quotedTextFontStyle        setEnabled: enabled];
    [textSubstitutionsFontStyle setEnabled: enabled];
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
    [restoreSettingsButton setEnabled: ![currentSet isEqualToEditingPreferenceSet:defaultSet]];
}

- (IBAction) styleSetHasChanged: (id) sender {
    // Update currentSet from preference pane
    {
        // Text section
        if (sender == fontFamily)                   currentSet.fontFamily               = [fontFamily titleOfSelectedItem];
        if (sender == fontSize)                     currentSet.fontSize                 = [fontSize intValue];
        if (sender == sourceColour)                 currentSet.sourcePaperColor         = [sourceColour color];
        if (sender == extensionColor)               currentSet.extensionPaperColor      = [extensionColor color];

        // Syntax highlighting section
        if (sender == enableSyntaxHighlighting)     currentSet.enableSyntaxHighlighting = ([enableSyntaxHighlighting state]==NSOnState);

        if (sender == headingsColor)                [[currentSet optionOfType: IFSHOptionHeadings]          setColour:     [headingsColor color]];
        if (sender == mainTextColor)                [[currentSet optionOfType: IFSHOptionMainText]          setColour:     [mainTextColor color]];
        if (sender == commentsColor)                [[currentSet optionOfType: IFSHOptionComments]          setColour:     [commentsColor color]];
        if (sender == quotedTextColor)              [[currentSet optionOfType: IFSHOptionQuotedText]        setColour:     [quotedTextColor color]];
        if (sender == textSubstitutionsColor)       [[currentSet optionOfType: IFSHOptionTextSubstitutions] setColour:     [textSubstitutionsColor color]];

        if (sender == headingsFontStyle)            [[currentSet optionOfType: IFSHOptionHeadings]          setFontStyle:  (int) [headingsFontStyle selectedTag]];
        if (sender == mainTextFontStyle)            [[currentSet optionOfType: IFSHOptionMainText]          setFontStyle:  (int) [mainTextFontStyle selectedTag]];
        if (sender == commentsFontStyle)            [[currentSet optionOfType: IFSHOptionComments]          setFontStyle:  (int) [commentsFontStyle selectedTag]];
        if (sender == quotedTextFontStyle)          [[currentSet optionOfType: IFSHOptionQuotedText]        setFontStyle:  (int) [quotedTextFontStyle selectedTag]];
        if (sender == textSubstitutionsFontStyle)   [[currentSet optionOfType: IFSHOptionTextSubstitutions] setFontStyle:  (int) [textSubstitutionsFontStyle selectedTag]];

        if (sender == headingsUnderline)            [[currentSet optionOfType: IFSHOptionHeadings]          setUnderline:  [headingsUnderline state] == NSOnState];
        if (sender == mainTextUnderline)            [[currentSet optionOfType: IFSHOptionMainText]          setUnderline:  [mainTextUnderline state] == NSOnState];
        if (sender == commentsUnderline)            [[currentSet optionOfType: IFSHOptionComments]          setUnderline:  [commentsUnderline state] == NSOnState];
        if (sender == quotedTextUnderline)          [[currentSet optionOfType: IFSHOptionQuotedText]        setUnderline:  [quotedTextUnderline state] == NSOnState];
        if (sender == textSubstitutionsUnderline)   [[currentSet optionOfType: IFSHOptionTextSubstitutions] setUnderline:  [textSubstitutionsUnderline state] == NSOnState];

        if (sender == headingsFontSize)             [[currentSet optionOfType: IFSHOptionHeadings]          setRelativeFontSize:  (int) [headingsFontSize selectedTag]];
        if (sender == mainTextFontSize)             [[currentSet optionOfType: IFSHOptionMainText]          setRelativeFontSize:  (int) [mainTextFontSize selectedTag]];
        if (sender == commentsFontSize)             [[currentSet optionOfType: IFSHOptionComments]          setRelativeFontSize:  (int) [commentsFontSize selectedTag]];
        if (sender == quotedTextFontSize)           [[currentSet optionOfType: IFSHOptionQuotedText]        setRelativeFontSize:  (int) [quotedTextFontSize selectedTag]];
        if (sender == textSubstitutionsFontSize)    [[currentSet optionOfType: IFSHOptionTextSubstitutions] setRelativeFontSize:  (int) [textSubstitutionsFontSize selectedTag]];

        // Tab width section
        if (sender == tabStopSlider)                currentSet.tabWidth                 = [tabStopSlider floatValue];

        // Indenting section
        if (sender == indentWrappedLines)           currentSet.indentWrappedLines      = ([indentWrappedLines state]     == NSOnState);
        if (sender == autoIndentAfterNewline)       currentSet.autoIndentAfterNewline  = ([autoIndentAfterNewline state] == NSOnState);
        if (sender == autoSpaceTableColumns)        currentSet.autoSpaceTableColumns   = ([autoSpaceTableColumns state]  == NSOnState);

        // Numbering section
        if (sender == autoNumberSections)           currentSet.autoNumberSections      = ([autoNumberSections state] == NSOnState);
    }

    // Update dependent UI elements
    if( sender == enableSyntaxHighlighting ) {
        [self updateDependentUIElements];
    }

    // Update application's preferences from currentSet
    [currentSet updateAppPreferencesFromSet];
}

-(BOOL) setFontFamilyUI:(NSString*) fontFamilyName {
    int index = 0;
    for( NSString* item in [fontFamily itemTitles] ) {
        if( [item compare: fontFamilyName
                  options:(NSStringCompareOptions) 0] == NSOrderedSame ) {
            [fontFamily selectItemAtIndex: index];
            return YES;
        }
        index++;
    }
    return NO;
}

- (void) reflectCurrentPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
	
    // Update currentSet based on application's current preferences
    [currentSet updateSetFromAppPreferences];

    // Update preference pane UI elements from currentSet
    
    // Text section
    if( ![self setFontFamilyUI: currentSet.fontFamily] ) {
        if( ![self setFontFamilyUI: @"Lucida Grande"] ) {
            [fontFamily selectItemAtIndex: 0];
        }
    }
    [fontSize setIntValue:    currentSet.fontSize];
    [sourceColour setColor:   currentSet.sourcePaperColor];
    [extensionColor setColor: currentSet.extensionPaperColor];

    // Syntax highlighting section
	[enableSyntaxHighlighting setState: currentSet.enableSyntaxHighlighting ? NSOnState : NSOffState];

    IFSyntaxHighlightingOption* option = (currentSet.options)[IFSHOptionHeadings];
    [headingsColor      setColor:          option.colour];
    [headingsFontStyle  selectItemAtIndex: option.fontStyle];
    [headingsUnderline  setState:          option.underline ? NSOnState : NSOffState];
    [headingsFontSize   selectItemAtIndex: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionMainText];
    [mainTextColor      setColor:          option.colour];
    [mainTextFontStyle  selectItemAtIndex: option.fontStyle];
    [mainTextUnderline  setState:          option.underline ? NSOnState : NSOffState];
    [mainTextFontSize   selectItemAtIndex: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionComments];
    [commentsColor      setColor:          option.colour];
    [commentsFontStyle  selectItemAtIndex: option.fontStyle];
    [commentsUnderline  setState:          option.underline ? NSOnState : NSOffState];
    [commentsFontSize   selectItemAtIndex: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionQuotedText];
    [quotedTextColor        setColor:          option.colour];
    [quotedTextFontStyle    selectItemAtIndex: option.fontStyle];
    [quotedTextUnderline    setState:          option.underline ? NSOnState : NSOffState];
    [quotedTextFontSize     selectItemAtIndex: option.relativeFontSize];

    option = (currentSet.options)[IFSHOptionTextSubstitutions];
    [textSubstitutionsColor     setColor:          option.colour];
    [textSubstitutionsFontStyle selectItemAtIndex: option.fontStyle];
    [textSubstitutionsUnderline setState:          option.underline ? NSOnState : NSOffState];
    [textSubstitutionsFontSize  selectItemAtIndex: option.relativeFontSize];

    // Tab width section
	[tabStopSlider  setMaxValue: [tabStopSlider bounds].size.width-12];
	[tabStopSlider  setFloatValue: [prefs tabWidth]];

    // Indenting section
    [indentWrappedLines     setState: currentSet.indentWrappedLines     ? NSOnState : NSOffState];
    [autoIndentAfterNewline setState: currentSet.autoIndentAfterNewline ? NSOnState : NSOffState];
    [autoSpaceTableColumns  setState: currentSet.autoSpaceTableColumns  ? NSOnState : NSOffState];

    // Numbering section
    [autoNumberSections     setState: currentSet.autoNumberSections     ? NSOnState : NSOffState];

    // Update dependent elements
    [self updateDependentUIElements];
    
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

- (IBAction) restoreDefaultSettings:(id) sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Restore"]];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Cancel"]];
    [alert setMessageText:     [IFUtility localizedString: @"Reset the editing preferences?"]];
    [alert setInformativeText: [IFUtility localizedString: @"This action cannot be undone."]];
    [alert setAlertStyle:NSWarningAlertStyle];

    if ([alert runModal] == NSAlertFirstButtonReturn ) {
        currentSet = [[IFEditingPreferencesSet alloc] init];
        
        [[IFPreferences sharedPreferences] startBatchEditing];
        [currentSet updateAppPreferencesFromSet];
        [[IFPreferences sharedPreferences] endBatchEditing];

        [self reflectCurrentPreferences];
    }
}

@end
