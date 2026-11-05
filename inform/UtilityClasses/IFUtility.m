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

static NSLock*       uniqueIdLock;
static unsigned long uniqueId = 1000;
NSTimeInterval const defaultTimeoutInterval = 60.0;
NSErrorDomain        INFORM_ERROR_DOMAIN = @"com.inform7.errors";


CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to) {
    return from + progress * (to - from);
}

CGFloat smoothstep(CGFloat t) {
    // https://en.wikipedia.org/wiki/Smoothstep
    return t*t*(3-2*t);
}

CGFloat smootherstep(CGFloat t) {
    // https://en.wikipedia.org/wiki/Smoothstep#Variations
    return t*t*t*(10+3*t*(2*t-5));
}

CGFloat easeOutQuad(CGFloat t) {
    return t*(2-t);
};

CGFloat easeOutCubic(CGFloat t) {
    t--;
    return t*t*t + 1;
};

#pragma mark - "IFUtility"
@implementation IFUtility

#pragma mark -  Initialisation
+ (void) initialize {
    uniqueIdLock = [[NSLock alloc] init];
}

#pragma mark - Generating unique IDs
+ (unsigned long) generateID {
    unsigned long new_id;
    [uniqueIdLock lock];
    new_id = uniqueId++;
    [uniqueIdLock unlock];
    return new_id;
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

    [alert beginSheetModalForWindow: window completionHandler:^(NSModalResponse returnCode) {
        
    }];
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

    if (window == nil) {
        NSModalResponse response = [alert runModal];
        [self modalYesNoResponse: response
                          window: window
                   modalDelegate: modalDelegate
                  didEndSelector: alertDidEndSelector
                     contextInfo: contextInfo];
        return;
    }

    [alert beginSheetModalForWindow: window completionHandler: ^(NSModalResponse response) {
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
#if 0
    NSMethodSignature * methodSignature = [[modalDelegate class]
                                    instanceMethodSignatureForSelector: alertDidEndSelector];
    NSInvocation * delegateInvocation = [NSInvocation
                                   invocationWithMethodSignature:methodSignature];

    [delegateInvocation setArgument:(void*)&window atIndex:2];
    [delegateInvocation setArgument:&returnCode atIndex:3];
    [delegateInvocation setArgument:(void*)&contextInfo atIndex:4];
    [delegateInvocation invoke];
#else
    // Hack!
    IMP imp = [modalDelegate methodForSelector: alertDidEndSelector];
    void (*func)(id, SEL, NSWindow*, NSInteger, void *) = (void *) imp;
    func(modalDelegate, alertDidEndSelector, window, returnCode, contextInfo);
#endif
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
    [IFUtility runAlertWarningWindow: window
                               title: @"Failed to Install Extension"
                             message: @"Failed to Install Extension Explanation"];
}

+ (NSArray<UTType*>*) contentTypesForFilenameExtensions: (NSArray<NSString*>*) extensions {
    NSMutableArray<UTType*>* types = [NSMutableArray array];
    for (NSString* extension in extensions) {
        UTType* type = [UTType typeWithFilenameExtension: extension];
        if (type != nil) {
            [types addObject: type];
        }
    }
    return types;
}

// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window {

    NSSavePanel* panel = [NSSavePanel savePanel];

    panel.allowedContentTypes = [IFUtility contentTypesForFilenameExtensions: @[@"txt"]];

    // Work out starting directory
    NSString*   prefString   = [[NSUserDefaults standardUserDefaults] objectForKey: @"IFTranscriptURL"];
    NSURL*      directoryURL = [NSURL URLWithString: prefString];
    if (directoryURL == nil) {
        directoryURL = [NSURL fileURLWithPath: NSHomeDirectory()];
    }

    panel.directoryURL = directoryURL;

    // Show it
    [panel beginSheetModalForWindow: window completionHandler:^(NSInteger returnCode)
     {
         if (returnCode != NSModalResponseOK) return;

         // Remember the directory we last saved into
         if ( panel.directoryURL.absoluteString != nil ) {
             NSString* writePrefString = panel.directoryURL.absoluteString;
             [[NSUserDefaults standardUserDefaults] setObject: writePrefString
                                                       forKey: @"IFTranscriptURL"];
         }

         // Save the data
         NSData* stringData = [string dataUsingEncoding: NSUTF8StringEncoding];
         [stringData writeToURL: panel.URL
                     atomically: YES];
     }];
}


#pragma mark - Sandboxing
+ (BOOL) isSandboxed {
    NSDictionary* environ = [NSProcessInfo processInfo].environment;
    return (nil != environ[@"APP_SANDBOX_CONTAINER_ID"]);
}

+(BOOL) hasFullscreenSupportFeature {
    // Lion (10.7) introduced fullscreen support
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+(BOOL) hasScrollElasticityFeature {
    // Lion (10.7) introduced elasticity on scrolling
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+ (BOOL) hasUpdatedToolbarFeature {
    return NSAppKitVersionNumber > NSAppKitVersionNumber10_10_Max;
}

+(void) performSelector:(SEL) selector object:(id) object {
    if( [object respondsToSelector: selector] ) {
        // ARC safe way to do performSelector (see http://stackoverflow.com/a/20058585/4786529 ) ...
        IMP imp = [object methodForSelector: selector];
        void (*func)(id, SEL) = (void *) imp;
        func(object, selector);
    }
}

+(NSDictionary*) adjustAttributesFontSize: (NSDictionary*) dictionary
                                     size: (CGFloat) fontSize {
    NSMutableDictionary* mutableResult = [dictionary mutableCopy];
    NSFont* font = mutableResult[NSFontAttributeName];
    if (@available(macOS 10.15, *)) {
        font = [font fontWithSize: fontSize];
    } else {
        font = [NSFont fontWithName: font.fontName
                               size: fontSize];
    }
    mutableResult[NSFontAttributeName] = font;
    return [mutableResult copy];
}

+(bool) unzip: (NSURL*) zipURL toDirectory:(NSURL*) targetDirectory {
    // see https://stackoverflow.com/questions/2296667/unzipping-a-file-in-cocoa
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError *error;

    // create a new empty folder (to get a clean unzip)
    [fm createDirectoryAtURL: targetDirectory
 withIntermediateDirectories: YES
                  attributes: nil
                       error: &error];

    //now create an unzip task
    // -o overwrites existing files
    // -x ignores any *.DS_Store and __MACOSX detritus (Note the -x argument must appear after the zip file)
    NSArray *arguments = @[@"-o", zipURL.path, @"-x", @"*.DS_Store", @"__MACOSX/*"];
    NSTask *unzipTask = [[NSTask alloc] init];
    unzipTask.launchPath = @"/usr/bin/unzip";
    unzipTask.currentDirectoryURL = targetDirectory;
    unzipTask.arguments = arguments;
    [unzipTask launch];
    [unzipTask waitUntilExit];

    if (unzipTask.terminationStatus != 0) {
        return FALSE;
    }
    return TRUE;
}

@end
