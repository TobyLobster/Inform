//
//  IFUtility.m
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import "IFUtility.h"
#import "IFPreferences.h"
#import "NSString+IFStringExtensions.h"
#import <Foundation/NSCache.h>
#import <objc/objc-runtime.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSErrorDomain        INFORM_ERROR_DOMAIN = @"com.inform7.errors";


CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to) {
    return from + progress * (to - from);
}

CGFloat easeOutCubic(CGFloat t) {
    t--;
    return t*t*t + 1;
};

#pragma mark - "IFUtility"
@implementation IFUtility

#pragma mark - Hosting the unit tests
+ (BOOL) isHostingUnitTests {
    return NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] != nil;
}

+ (void) stopTestHostWithLeftoverHome {
    NSDictionary<NSString*, NSString*>* environment = NSProcessInfo.processInfo.environment;
    if ([self isTestHostWithLeftoverHomeInEnvironment: environment]) {
        NSLog(@"The tests' home folder %@ was there as the test host started, so the host has the user's "
              @"preferences. It's stopped, and the tests that were left aren't run.",
              environment[@"CFFIXED_USER_HOME"]);
        exit(EXIT_FAILURE);
    }
}

+ (BOOL) isTestHostWithLeftoverHomeInEnvironment: (NSDictionary<NSString*, NSString*>*) environment {
    NSString* home = environment[@"CFFIXED_USER_HOME"];
    return environment[@"XCTestConfigurationFilePath"] != nil && home != nil &&
           [NSFileManager.defaultManager fileExistsAtPath: home];
}

#pragma mark - Alert dialogs
+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: YES
                           title: [self localizedString: title]
                         message: @"%@", contents];
}

+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
               informativeText: (NSString*) text {
    [self runAlertWarningWindow: window
                          title: title
                        message: @"%@", text];
}

+ (void) runAlertWarningWindow: (NSWindow*) window
                localizedTitle: (NSString*) title
               informativeText: (NSString*) text {
    [[self class] runAlertWindow: window
                       localized: YES
                         warning: YES
                           title: title
                         message: @"%@", text];
}

+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: NO
                           title: [self localizedString: title]
                         message: @"%@", contents];
}

+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                   informativeText: (NSString*) text {
    [self runAlertInformationWindow: window
                              title: title
                            message: @"%@", text];
}


+ (void) runAlertWindow: (NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: alreadyLocalized ? formatString : [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: @"OK"]];
    alert.messageText = alreadyLocalized ? title : [self localizedString: title];
    alert.informativeText = contents;
    alert.alertStyle = warningStyle ? NSAlertStyleWarning : NSAlertStyleInformational;

    [self showAlert: alert
          forWindow: window
  completionHandler: ^(NSModalResponse returnCode) {

    }];
}

+ (void) showAlert: (NSAlert*) alert
         forWindow: (NSWindow*) window
 completionHandler: (void (^)(NSModalResponse response)) handler {
    if (window != nil) {
        [alert beginSheetModalForWindow: window completionHandler: handler];
        return;
    }

    // A sheet on no window doesn't appear, so the alert is run modally, unless nobody is there to close it
    if ([self isHostingUnitTests]) {
        NSLog(@"Alert not shown while hosting the unit tests: %@ %@", alert.messageText, alert.informativeText);
        handler(NSModalResponseAbort);
        return;
    }
    handler([alert runModal]);
}

+ (void) beginSavePanel: (NSSavePanel*) panel
              forWindow: (NSWindow*) window
      completionHandler: (void (^)(NSModalResponse result)) handler {
    [panel beginSheetModalForWindow: window completionHandler: handler];
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString
                        args: (va_list) args {
    NSString* contents = [[NSString alloc] initWithFormat: formatString
                                                 arguments: args];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  yes];
    [alert addButtonWithTitle:  no];
    alert.messageText = title;
    alert.informativeText = contents;
    alert.alertStyle = NSAlertStyleInformational;
    if (@available(macOS 11.0, *)) {
        switch (desIdx) {
            case NSNotFound:
                // do nothing
                break;
                
            case 0:
            case 1:
                alert.buttons[desIdx].hasDestructiveAction = YES;
                break;

            default:
                break;
        }
    }

    [self showAlert: alert
          forWindow: window
  completionHandler: ^(NSModalResponse response) {
        [self modalYesNoResponse: response
                          window: window
                   modalDelegate: modalDelegate
                  didEndSelector: alertDidEndSelector
                     contextInfo: contextInfo];
    }];
}

+ (void) modalYesNoResponse: (NSModalResponse) returnCode
                     window: (NSWindow*) window
              modalDelegate: (id) modalDelegate
             didEndSelector: (SEL) alertDidEndSelector
                contextInfo: (void *) contextInfo {
    if (!modalDelegate || !alertDidEndSelector) {
        return;
    }
    // Hack!
    IMP imp = [modalDelegate methodForSelector: alertDidEndSelector];
    void (*func)(id, SEL, NSWindow*, NSInteger, void *) = (void *) imp;
    func(modalDelegate, alertDidEndSelector, window, returnCode, contextInfo);
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
                     message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    [self runAlertYesNoWindow:window
                        title:title
                          yes:yes
                           no:no
                modalDelegate:modalDelegate
               didEndSelector:alertDidEndSelector
                  contextInfo:contextInfo
             destructiveIndex:NSNotFound
                      message:formatString
                         args:args];
    va_end(args);
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    [self runAlertYesNoWindow:window
                        title:title
                          yes:yes
                           no:no
                modalDelegate:modalDelegate
               didEndSelector:alertDidEndSelector
                  contextInfo:contextInfo
             destructiveIndex:desIdx
                      message:formatString
                         args:args];
    va_end(args);
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
             informativeText: (NSString*) text {
    [self runAlertYesNoWindow: window
                        title: title
                          yes: yes
                           no: no
                modalDelegate: modalDelegate
               didEndSelector: alertDidEndSelector
                  contextInfo: contextInfo
                      message: @"%@", text];
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
             informativeText: (NSString*) text {
    [self runAlertYesNoWindow: window
                        title: title
                          yes: yes
                           no: no
                modalDelegate: modalDelegate
               didEndSelector: alertDidEndSelector
                  contextInfo: contextInfo
             destructiveIndex: desIdx
                      message: @"%@", text];
}

+ (void) showExtensionError: (IFExtensionResult) result
                 withWindow: (NSWindow*) window {
    // TODO: Do we want to customise the error message depending on the IFExtensionResult?
    switch (result) {
        case IFExtensionNotFound:
            break;
        case IFExtensionNotValid:
            break;
        case IFExtensionAlreadyExists:
            break;
        case IFExtensionCantWriteDestination:
            break;
        case IFExtensionSuccess:
        default:
            return;
    }
    [self runAlertWarningWindow: window
                          title: @"Failed to Install Extension"
                        message: @"Failed to Install Extension Explanation"];
}

@end
