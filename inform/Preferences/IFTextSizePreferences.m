//
//  IFTextSizePreferences.m
//  Inform
//
//  Created by Toby Nelson on 2014.
//

#import "IFTextSizePreferences.h"

#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFTextSizePreferences {
    IBOutlet NSPopUpButton* appTextSize;
}

- (instancetype) init {
	self = [super initWithNibName: @"TextSizePreferences"];
	
	if (self) {
		[self reflectCurrentPreferences];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
	}
	
	return self;
}

// = Setting ourselves up =

- (void) reflectCurrentPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];

	[appTextSize selectItemWithTag: [prefs appFontSizeMultiplierEnum]];
}

- (IBAction) setPreference: (id) sender {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
	
	if (sender == appTextSize) [prefs setAppFontSizeMultiplierEnum: (int) [appTextSize selectedTag]];
}

// = PreferencePane overrides =

- (NSString*) preferenceName {
	return @"Text Size";
}

- (NSImage*) toolbarImage {
	NSImage* image = [NSImage imageNamed: NSImageNameFontPanel];
	return image;
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Text size preferences tooltip"];
}

@end
