//
//  IFToolbarManager.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

@class IFProgress;
@class IFProjectController;
@class IFToolbarStatusView;

@interface IFToolbarManager : NSObject<NSToolbarDelegate>

- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (instancetype) initWithProjectController:(IFProjectController*) pc NS_DESIGNATED_INITIALIZER;
- (void) updateSettings;
- (void) setToolbar;
- (void) validateVisibleItems;
- (void) windowDidResize: (NSNotification*) notification;

// Status Messages
- (void) showMessage: (NSString*) message;
@property (atomic, readonly, copy)    NSString *      toolbarIdentifier;
@property (atomic, readonly, strong)  NSPopUpButton*  testCasesPopUpButton;
@property (atomic, readonly, strong)  NSButton*       goButton;
/// Array of availabale test cases
@property (atomic, readonly, strong)  NSArray*        testCases;

@property (atomic, readonly, strong)  IFProjectController* projectController;

// Progress
- (void) updateProgress;
- (void) addProgressIndicator: (IFProgress*) indicator;
- (void) removeProgressIndicator: (IFProgress*) indicator;
- (void) progressIndicator: (IFProgress*) indicator
				percentage: (CGFloat) newPercentage;
- (void) progressIndicator: (IFProgress*) indicator
				   message: (NSString*) newMessage;
- (void) progressIndicatorStartStory: (IFProgress*) indicator;
- (void) progressIndicatorStopStory: (IFProgress*) indicator;
- (void) progressIndicatorStartProgress: (IFProgress*) indicator;
- (void) progressIndicatorStopProgress: (IFProgress*) indicator;
-(void) cancelProgress;

// Extension projects
-(void) setIsExtensionProject:(BOOL) isExtensionProject;
-(void) setTestCases:(NSArray*) testCasesArray;
-(NSString*) getTestCase:(int) index;
-(int) getNumberOfTestCases;
-(int) getTestCaseIndex;

-(BOOL) selectTestCase:(NSString*) testCase;

-(void) redrawToolbar;

@property (atomic, readonly, copy) NSString *currentTestCase;

@end
