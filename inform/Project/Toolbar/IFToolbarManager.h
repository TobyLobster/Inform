//
//  IFToolbarManager.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

NS_ASSUME_NONNULL_BEGIN

@class IFProgress;
@class IFProjectController;
@class IFToolbarStatusView;

@interface IFToolbarManager : NSObject<NSToolbarDelegate, NSToolbarItemValidation>

- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (instancetype) initWithProjectController:(IFProjectController*) pc NS_DESIGNATED_INITIALIZER;
- (void) setToolbar;
- (void) validateVisibleItems;
- (void) windowDidResize: (NSNotification*) notification;

// Status Messages
- (void) showMessage: (NSString*) message;
@property (atomic, readonly, copy)              NSString *      toolbarIdentifier;
@property (atomic, readonly, strong, nullable)  NSPopUpButton*  testCasesPopUpButton;   // nil until the toolbar has made it
/// Array of availabale test cases
@property (atomic, readonly, strong, nullable)  NSArray<NSDictionary<NSString*, id>*>* testCases;

@property (atomic, readonly, weak, nullable)    IFProjectController* projectController;

// Progress
- (void) updateProgress;
- (void) addProgressIndicator: (IFProgress*) indicator;
- (void) removeProgressIndicator: (IFProgress*) indicator;
- (void) progressIndicator: (IFProgress*) indicator
				percentage: (CGFloat) newPercentage;
- (void) progressIndicator: (IFProgress*) indicator
				   message: (nullable NSString*) newMessage;
- (void) progressIndicatorStartStory: (IFProgress*) indicator;
- (void) progressIndicatorStopStory: (IFProgress*) indicator;
- (void) progressIndicatorStartProgress: (IFProgress*) indicator;
- (void) progressIndicatorStopProgress: (IFProgress*) indicator;
-(void) cancelProgress;

// Extension projects
-(void) setTestCases:(nullable NSArray<NSDictionary<NSString*, id>*>*) testCasesArray;
-(nullable NSString*) getTestCase:(int) index;
@property (NS_NONATOMIC_IOSONLY, getter=getNumberOfTestCases, readonly) int numberOfTestCases;
@property (NS_NONATOMIC_IOSONLY, getter=getTestCaseIndex, readonly) int testCaseIndex;

-(BOOL) selectTestCase:(NSString*) testCase;

-(void) redrawToolbar;

@property (atomic, readonly, copy, nullable) NSString *currentTestCase;

@end

NS_ASSUME_NONNULL_END
