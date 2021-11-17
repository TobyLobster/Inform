/* ZoomGameInfoController */

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomResourceDrop.h>

/// Controller for the game info window
@interface ZoomGameInfoController : NSWindowController <NSOpenSavePanelDelegate> {
	IBOutlet NSMenu*      genreMenu;
	
	IBOutlet NSTextField* gameName;
	IBOutlet NSTextField* headline;
	IBOutlet NSTextField* author;
	IBOutlet NSComboBox* genre;
	IBOutlet NSTextField* year;
	IBOutlet NSTextField* group;
	
	IBOutlet NSTextView*  comments;
	IBOutlet NSTextView*  teaser;
	
	IBOutlet NSPopUpButton* zarfRating;
	IBOutlet NSSlider*      rating;
	IBOutlet NSButton*      ratingOn;
	
	IBOutlet ZoomResourceDrop* resourceDrop;
	IBOutlet NSTextField*      resourceFilenameField;
	IBOutlet NSButton*         chooseResourceButton;
	
	IBOutlet NSTabView*     tabs;
	
	ZoomStory* gameInfo;
	
	id infoOwner;
}

@property (class, readonly, retain) ZoomGameInfoController *sharedGameInfoController;

// Interface actions
- (IBAction)selectGenre:(id)sender;
- (IBAction)showGenreMenu:(id)sender;
- (IBAction)activateRating:(id)sender;
- (IBAction)chooseResourceFile:(id)sender;

// Setting up the game info window
@property (nonatomic, retain) ZoomStory *gameInfo;

@property (strong) id infoOwner;

// Reading the current (updated) contents of the game info window
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *headline;
@property (readonly, copy) NSString *author;
@property (readonly, copy) NSString *genre;
@property (readonly) int year;
@property (readonly, copy) NSString *group;
@property (readonly, copy) NSString *comments;
@property (readonly, copy) NSString *teaser;
@property (readonly) IFMB_Zarfian zarfRating;
@property (readonly) float rating;
@property (readonly, copy) NSString *resourceFilename;

// Read them all at once
- (NSDictionary<NSString*,id>*) dictionary;

@end
