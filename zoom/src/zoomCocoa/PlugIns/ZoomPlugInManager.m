//
//  ZoomPlugInManager.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInManager.h"
#import <ZoomPlugIns/ZoomPlugInInfo.h>

NSString*const ZoomPlugInInformationChangedNotification = @"ZoomPlugInInformationChangedNotification";

@implementation ZoomPlugInManager {
	/// The plugin lock
	NSLock* pluginLock;
	
	/// The bundles containing the loaded plugins
	NSMutableArray<NSBundle*>* pluginBundles;
	/// The ZoomPlugIn classes from the bundles
	NSMutableArray<Class>* pluginClasses;
	/// Array mapping plugin versions to names
	NSMutableDictionary<NSString*,NSString*>* pluginsToVersions;
	
	/// Information about all plugins known about by this object (including those that live elsewhere)
	NSMutableArray* pluginInformation;
	
	/// The path of the last plugin we retrieved a plist for
	NSString* lastPlistPlugin;
	/// The plist retrieved from the lastPlistPlugin
	NSDictionary* lastPlist;
	
	/// Check for updates URLs that are still waiting to be processed
	NSMutableArray<NSURL*>* checkUrls;
	/// The last check for updates request that was sent
	NSURLRequest* lastRequest;
	/// The connection for the last request
	NSURLSessionDataTask *checkConnectionTask;
	/// The response to the last check for updates request
	NSURLResponse* checkResponse;
	/// The data returned for the last check for updates request
	NSMutableData* checkData;
	
	/// Set to \c YES if a restart is required
	BOOL restartRequired;
	/// \c YES if we're downloading updates
	BOOL downloading;
	/// The plug in that we're performing a download for
	ZoomPlugInInfo* downloadInfo;
	/// The active download for this object
	ZoomDownload* currentDownload;
	
	NSURLSession *session;
}

#pragma mark - Initialisation

+ (ZoomPlugInManager*) sharedPlugInManager {
	static ZoomPlugInManager* sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[ZoomPlugInManager alloc] init];
	});
	
	return sharedManager;
}

+ (NSString*) appSupport {
	BOOL isDir;
	
	// Start with the library directory
	NSArray* libDirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	if ([libDirs count] == 0) {
		NSLog(@"Could not locate library directory!");
		return nil;
	}
	
	// Use a Zoom directory inside for the rest of the contents
	NSString *supportDir = [[libDirs objectAtIndex: 0] stringByAppendingPathComponent: @"Zoom"];
	if (![[NSFileManager defaultManager] fileExistsAtPath: supportDir isDirectory: &isDir]) {
		isDir = YES;
		[[NSFileManager defaultManager] createDirectoryAtPath: supportDir withIntermediateDirectories:NO attributes:nil error:NULL];
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: supportDir]) {
		NSLog(@"Could not locate Zoom's app support directory");
		return nil;
	}
	
	if (!isDir) {
		NSLog(@"%@ is not a directory!", supportDir);
		return nil;
	}
	
	// Got the result
	return supportDir;
}

+ (NSString*) plugInsPath {
	return [[[self class] appSupport] stringByAppendingPathComponent: @"PlugIns"];
}

+ (NSString*) pendingPlugInsPath {
	return [[[self class] appSupport] stringByAppendingPathComponent: @"Pending PlugIns"];
}

+ (NSString*) disabledPlugInsPath {
	return [[[self class] appSupport] stringByAppendingPathComponent: @"Disabled PlugIns"];
}

- (id) init {
	self = [super init];
	
	if (self) {
		pluginLock = [[NSLock alloc] init];
		
		NSURLSessionConfiguration *config = [NSURLSessionConfiguration.ephemeralSessionConfiguration copy];
		config.networkServiceType = NSURLNetworkServiceTypeBackground;
		session = [NSURLSession sessionWithConfiguration: config
												delegate: self
										   delegateQueue: nil];
	}
	
	return self;
}

- (void) finishedWithObject {
	currentDownload = nil;
	
	downloadInfo = nil;
	
	pluginInformation = nil;
}

#pragma mark - Setting the delegate

@synthesize delegate;

#pragma mark - Dealing with existing plugins

- (void) loadPlugIn: (NSString*) pluginBundlePath {
	NSBundle* pluginBundle = [NSBundle bundleWithPath: pluginBundlePath];
	
	NSString* version = [self versionForBundle: pluginBundlePath];
	NSString* name = [self nameForBundle: pluginBundlePath];
	
	if (pluginBundlePath != nil && name == nil) {
		NSLog(@"== Not a valid plugin: %@", pluginBundlePath);
	}
	
	if (pluginBundle != nil && name != nil) {
		@try {
			if ([pluginBundle load]) {
#if VERBOSITY >= 1
				NSLog(@"== Plugin loaded: %@", [pluginBundlePath stringByDeletingPathExtension]);
#endif
				[pluginBundles addObject: pluginBundle];
				
				[pluginsToVersions setObject: version
									  forKey: name];
				
				Class primaryClass = [pluginBundle principalClass];
				[pluginClasses addObject: primaryClass];
#if VERBOSITY >= 2
				NSLog(@"=== Principal class: %@", [primaryClass description]);
#endif
			}
		} @catch (NSException *exception) {
			NSLog(@"Plugin %@ failed %@", pluginBundle, exception.callStackSymbols);
		} @finally {
		}
	}	
}

- (void) loadPluginsFromPath: (NSString*) pluginPath {
	if (!pluginBundles) pluginBundles = [[NSMutableArray alloc] init];
	if (!pluginClasses) pluginClasses = [[NSMutableArray alloc] init];
	if (!pluginsToVersions) pluginsToVersions = [[NSMutableDictionary alloc] init];
	
	pluginInformation = nil;
	
#if VERBOSITY >= 2
	NSLog(@"= Loading plugins from: %@", pluginPath);
#endif
	NSEnumerator* pluginEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: pluginPath error: NULL] objectEnumerator];
	
	NSString* plugin;
	for (plugin in pluginEnum) {
#if VERBOSITY >= 2
		NSLog(@"= Found file: %@", plugin);
#endif
		if ([[[plugin pathExtension] lowercaseString] isEqualToString: @"bundle"]
			|| [[[plugin pathExtension] lowercaseString] isEqualToString: @"plugin"]
			|| [[[plugin pathExtension] lowercaseString] isEqualToString: @"zoomplugin"]) {
			NSString* pluginBundlePath = [pluginPath stringByAppendingPathComponent: plugin];
			[self loadPlugIn: pluginBundlePath];
		}
	}
	
	[self pluginInformationChanged];
}

- (void) loadPlugIns {
	if (pluginBundles == nil) {
#if VERBOSITY >= 2
		NSLog(@"= Will load plugin bundles now");
#endif
		
		// Load the plugins
		NSString* pluginPath = [[NSBundle mainBundle] builtInPlugInsPath];
		[self loadPluginsFromPath: pluginPath];
		
		if ([pluginClasses count] == 0) {
			NSString* pluginPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents/PlugIns"];
#if VERBOSITY >=1
			NSLog(@"= Trying harder to load plugins");
#endif
			[self loadPluginsFromPath: pluginPath];
		}
		
		NSString* morePlugInsPath = [[self class] plugInsPath];
		if (morePlugInsPath) {
			if (![[NSFileManager defaultManager] fileExistsAtPath: morePlugInsPath]) {
				[[NSFileManager defaultManager] createDirectoryAtPath: morePlugInsPath 
										  withIntermediateDirectories:NO
														   attributes:nil
																error:NULL];
			}
			[self loadPluginsFromPath: morePlugInsPath];
		}
	}	
}

- (Class) plugInForURL: (NSURL*) fileName {
#if VERBOSITY >= 3
	NSLog(@"= Seeking a plugin for %@", filename);
#endif
	
	[self loadPlugIns];
	
	for (Class pluginClass in pluginClasses) {
		if ([pluginClass canRunURL: fileName]) {
#if VERBOSITY >=3
			NSLog(@"= Found %@", [pluginClass description]);
#endif
			return pluginClass;
		}
	}
	
#if VERBOSITY >= 3
	NSLog(@"= No plugins found (will try z-code)", filename);
#endif
	return nil;
}

- (Class) plugInForFile: (NSString*) filename {
	return [self plugInForURL: [NSURL fileURLWithPath: filename]];
}

- (ZoomPlugIn*) instanceForFile: (NSString*) filename {
	return [self instanceForURL: [NSURL fileURLWithPath: filename]];
}

- (ZoomPlugIn*) instanceForURL: (NSURL*) filename{
	[pluginLock lock];
	
	Class pluginClass = [self plugInForURL: filename];
	if (pluginClass == nil) {
		[pluginLock unlock];
		return nil;
	}
	
#if VERBOSITY >= 3
	NSLog(@"= Instantiating %@ for %@", [pluginClass description], filename);
#endif
	ZoomPlugIn* instance = [[pluginClass alloc] initWithURL: filename];
	
	[pluginLock unlock];
	return instance;	
}

- (NSArray*) pluginBundles {
	return pluginBundles;
}

- (NSArray*) loadedPlugIns {
	return [pluginsToVersions allKeys];
}

- (NSString*) versionForPlugIn: (NSString*) plugin {
	return [pluginsToVersions objectForKey: plugin];
}

- (NSArray*) arrayForVersion: (NSString*) version {
	return [version componentsSeparatedByString:@"."];
}

- (BOOL) version: (NSString*) oldVersion
	 isNewerThan: (NSString*) newVersion {
	// Divide the two versions into strings separated by '.'s
	NSArray* oldVersionArray = [self arrayForVersion: oldVersion];
	NSArray* newVersionArray = [self arrayForVersion: newVersion];
	
	NSInteger length = [oldVersionArray count];
	if ([newVersionArray count] > length) length = [newVersionArray count];
	NSInteger x;
	for (x=length-1; x>=0; x--) {
		NSString* old = x<[oldVersionArray count]?[oldVersionArray objectAtIndex: x]:@"0";
		NSString* new = x<[newVersionArray count]?[newVersionArray objectAtIndex: x]:@"0";
		
		if ([old intValue] > [new intValue]) return YES;
	}
	
	return NO;
}

- (NSArray<NSString*>*)pluginSupportedFileTypes {
	NSMutableArray *utis = [[NSMutableArray alloc] initWithCapacity:pluginClasses.count * 2];
	for (Class plugClass in pluginClasses) {
		[utis addObjectsFromArray: [plugClass supportedFileTypes]];
	}
	return utis;
}

#pragma mark - Getting information about plugins

- (NSDictionary*) plistForBundleAtPath: (NSString*) pluginBundle {
	if (pluginBundle == nil) return nil;
	
	// Standardise the plugin path
	pluginBundle = [pluginBundle stringByStandardizingPath];
	
	// Use the cached version of the plist if we've already got it loaded
	if ([pluginBundle isEqualToString: lastPlistPlugin]) {
		return lastPlist;
	}
	
	// Clear the cache
	lastPlistPlugin = [pluginBundle copy];
	lastPlist = nil;
		
	// Check that the bundle exists and is a directory
	BOOL exists;
	BOOL isDir;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: pluginBundle
												  isDirectory: &isDir];
	if (!exists || !isDir) {
		return nil;
	}
	
	// Check that the plist file exists
	NSString* plistPath = [[pluginBundle stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Info.plist"];
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: plistPath
												  isDirectory: &isDir];
	if (!exists || isDir) {
		return nil;
	}
	
	// Try to load the plist file from the bundle
	NSDictionary* plistDictionary = [NSDictionary dictionaryWithContentsOfFile: plistPath];
	if (plistDictionary == nil) {
		return nil;
	}
	
	// Must contain a ZoomPlugin key
	if (![plistDictionary objectForKey: @"ZoomPlugin"]) {
		return nil;
	}
	
	if (![[plistDictionary objectForKey: @"ZoomPlugin"] isKindOfClass: [NSDictionary class]]) {
		return nil;
	}
	
	// Plugin is OK: return the result
	return lastPlist = plistDictionary;
}

- (NSString*) nameForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundleAtPath: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"DisplayName"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = @"Untitled";
	}
	
	return result;
}

- (NSString*) authorForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundleAtPath: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"Author"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = [zoomPlugins objectForKey: @"InterpreterAuthor"];
	}
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;	
}

- (NSString*) versionForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundleAtPath: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"Version"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;		
}

- (NSString*) terpAuthorForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundleAtPath: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"InterpreterAuthor"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = [zoomPlugins objectForKey: @"Author"];
	}
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;		
}

#pragma mark - Getting information about plugins

- (void) pluginInformationChanged {
	if (delegate && [delegate respondsToSelector: @selector(pluginInformationChanged)]) {
		[delegate pluginInformationChanged];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomPlugInInformationChangedNotification
														object: self];
}

static int RankForStatus(ZoomPlugInStatus status) {
	if (status == ZoomPlugInDownloadFailed
		|| status == ZoomPlugInInstallFailed) {
		return 6;
	}
	if (status == ZoomPluginUpdateAvailable 
		|| status == ZoomPlugInNew 
		|| status == ZoomPlugInDownloaded
		|| status == ZoomPlugInDownloading) {
		return 5;
	}
	if (status == ZoomPlugInUpdated) {
		return 4;
	}
	if (status == ZoomPlugInNotKnown || status == ZoomPlugInDisabled) {
		return 0;
	}
	
	return 1;
}

- (void) sortInformation {
	// Sorts the plugin information array
	[pluginInformation sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		ZoomPlugInInfo* first = obj1;
		ZoomPlugInInfo* second = obj2;
		
		// First sort by status: unknown at the bottom, new and updated at the top
		ZoomPlugInStatus firstStatus = [first status];
		ZoomPlugInStatus secondStatus = [second status];
		
		if (RankForStatus(firstStatus) < RankForStatus(secondStatus))
			return NSOrderedDescending;
		else if (RankForStatus(firstStatus) > RankForStatus(secondStatus))
			return NSOrderedAscending;
		
		// Then sort by the name of the plugin
		return [[first name] caseInsensitiveCompare: [second name]];
	}];
}

- (void) addPlugInsFromDirectory: (NSString*) directory
						  status: (ZoomPlugInStatus) status {
	BOOL exists;
	BOOL isDir;
	exists = [[NSFileManager defaultManager] fileExistsAtPath: directory
												  isDirectory: &isDir];
	
	if (exists && isDir) {
		NSArray* plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: directory error:NULL];
		for (NSString* pluginName in plugins) {
			NSString* fullPath = [directory stringByAppendingPathComponent: pluginName];
			
			// Get the info object
			ZoomPlugInInfo* information = [[ZoomPlugInInfo alloc] initWithBundleFilename: fullPath];
			if (information == nil) continue;
			[information setStatus: status];
			
			// Store in the array
			[pluginInformation addObject: information];
		}
	}	
}

- (void) setupInformation {
	// Sets up the initial plugin information array
	pluginInformation = [[NSMutableArray alloc] init];
	
	// Get the information for all of the loaded plugins
	for (NSBundle* bundle in pluginBundles) {
		// Get the info object
		ZoomPlugInInfo* information = [[ZoomPlugInInfo alloc] initWithBundleFilename: [bundle bundlePath]];
		if (information == nil) continue;
		
		// Store in the array
		[pluginInformation addObject: information];
	}
	
	// Get the information for any plugins that are installed but disabled
	NSString* disabledPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns Disabled"];
	[self addPlugInsFromDirectory: disabledPath
						   status: ZoomPlugInDisabled];

	NSString* disabledPath2 = [[self class] disabledPlugInsPath];
	[self addPlugInsFromDirectory: disabledPath2
						   status: ZoomPlugInDisabled];
	
	// Get the information for any plugins that are waiting to be installed
	NSString* waitingPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns Upgraded"];
	[self addPlugInsFromDirectory: waitingPath
						   status: ZoomPlugInUpdated];

	NSString* waitingPath2 = [[self class] pendingPlugInsPath];
	[self addPlugInsFromDirectory: waitingPath2
						   status: ZoomPlugInUpdated];
	
	// Sort the plugin array
	[self sortInformation];
}

- (NSArray*) informationForPlugins {
	if (pluginInformation == nil) [self setupInformation];
	
	return pluginInformation;
}

- (void) startNextCheck {
	if (lastRequest != nil) return;

    // Plug-in updates are disabled for now
    [checkUrls removeAllObjects];
    if (delegate && [delegate respondsToSelector: @selector(finishedCheckingForUpdates)]) {
        [delegate finishedCheckingForUpdates];
    }
    return;
	
	// Get the next URL to check
	NSURL* nextUrl = nil;
	if ([checkUrls count] > 0) {
		nextUrl = [checkUrls lastObject];
		[checkUrls removeLastObject];
	}
	
	// We've finished if the next URL is nil
	if (nextUrl == nil) {
		checkUrls = nil;
		
		if (delegate && [delegate respondsToSelector: @selector(finishedCheckingForUpdates)]) {
			[delegate finishedCheckingForUpdates];
		}
		return;
	}
	
	// Create a new request
	NSLog(@"Checking for plug-in updates from %@", nextUrl);
	lastRequest = [NSURLRequest requestWithURL: nextUrl
									cachePolicy: NSURLRequestReloadIgnoringCacheData
								timeoutInterval: 20];
	checkConnectionTask = [session dataTaskWithRequest: lastRequest];
	checkConnectionTask.taskDescription = @"Zoom plug-in update check";
}

- (void) checkForUpdatesFromURLs: (NSArray*) urls {
	// Get the set of URLs to check
	NSSet* uniqueUrls = [NSSet setWithArray: urls];
	
	// Store the set of URLs to check
	checkUrls = [[uniqueUrls allObjects] mutableCopy];
	
	// Notify the delegate that we're starting to check for updates
	if (delegate && [delegate respondsToSelector: @selector(checkingForUpdates)]) {
		[delegate checkingForUpdates];
	}
	
	// Start the next check for updates request
	[self startNextCheck];
}

- (void) checkForUpdates {
	// Build the list of places to check
	NSMutableArray* whereToCheck = [[NSMutableArray alloc] init];
	
	if (checkUrls != nil) {
		[whereToCheck addObjectsFromArray: checkUrls];
	}
	
	// If any of the plugins specify an update URL, add that to the list
	NSArray* pluginInfo = [self informationForPlugins];
	for (ZoomPlugInInfo* plugin in pluginInfo) {
		if ([plugin status] == ZoomPlugInInstalled && [plugin updateUrl] != nil) {
			[whereToCheck addObject: [plugin updateUrl]];
		}
	}
	
#ifdef DEVELOPMENT
	[whereToCheck addObject: [NSURL URLWithString: [[NSBundle mainBundle] objectForInfoDictionaryKey: @"ZoomPluginFeedTestURL"]]];
#endif
	[whereToCheck addObject: [NSURL URLWithString: [[NSBundle mainBundle] objectForInfoDictionaryKey: @"ZoomPluginFeedURL"]]];
	
	// Start the check
	[self checkForUpdatesFromURLs: whereToCheck];
}

- (BOOL) addUpdatedPlugin: (ZoomPlugInInfo*) plugin {
    // This is disabled for now
    return NO;
    
	// Find the old plugin that matches this one
	ZoomPlugInInfo* oldPlugIn = nil;
	
	for (ZoomPlugInInfo* maybePlugin in [self informationForPlugins]) {
		if ([[plugin name] isEqualToString: [maybePlugin name]]) {
			oldPlugIn = maybePlugin;
		}
	}
	
	// If the old plugin is in the 'download failed' status, then reset it
	if (oldPlugIn != nil && ([oldPlugIn status] == ZoomPlugInDownloadFailed || [oldPlugIn status] == ZoomPlugInInstallFailed)) {
		if ([oldPlugIn updateInfo] == nil && ![[oldPlugIn location] isFileURL]) {
			[pluginInformation removeObjectIdenticalTo: oldPlugIn];
			oldPlugIn = nil;
		} else {
			[oldPlugIn setUpdateInfo: nil];
		}
	}
	
	// If there is no old plugin, then this plugin is new
	if (oldPlugIn == nil) {
		[plugin setStatus: ZoomPlugInNew];
		[pluginInformation addObject: plugin];
		[self sortInformation];
		return YES;
	}
	
	// If there is an old plugin, then compare the versions and mark the old plugin as updated if there's a new version available
	if ([self version: [plugin version]
		  isNewerThan: [oldPlugIn version]]) {
		ZoomPlugInInfo* oldUpdate = [oldPlugIn updateInfo];
		
		if (oldUpdate == nil || [self version: [plugin version]
								  isNewerThan: [oldUpdate version]]) {
			[oldPlugIn setUpdateInfo: plugin];
			[oldPlugIn setStatus: ZoomPluginUpdateAvailable];
			[self sortInformation];
			return YES;
		}
	}
	
	return NO;
}

#pragma mark - Handling URL events

- (void)  URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
  didReceiveResponse:(NSURLResponse *)response
   completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
	if (dataTask == checkConnectionTask) {
		// Got a response to the last check for updates URL
		checkResponse = response;
		checkData = [[NSMutableData alloc] init];
		completionHandler(NSURLSessionResponseAllow);
	} else {
		completionHandler(NSURLSessionResponseCancel);
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	if (dataTask == checkConnectionTask) {
		[checkData appendData: data];
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
	if (task == checkConnectionTask) {
		if (error) {
			// Got a response to the last check for updates URL
			checkResponse = nil;
			
			NSLog(@"Error while checking for updates: %@", error);
			return;
		}
		NSDictionary* result = nil;
		
		if (checkResponse != nil && checkData != nil) {
			// Handle the response
			result = [NSPropertyListSerialization propertyListWithData: checkData
															   options: NSPropertyListImmutable
																format: nil
																 error: nil];
		}
		
		if (result != nil) {
			// Iterate through the values in the result to get the current versions of the plugins specified in the XML file
			NSEnumerator* valueEnum = [[result allValues] objectEnumerator];
			BOOL updated = NO;
			for (NSDictionary* value in valueEnum) {
				// The entries must be dictionaries
				if (![value isKindOfClass: [NSDictionary class]])
					continue;
				
				// Work out the plugin information for this entry
				ZoomPlugInInfo* info = [[ZoomPlugInInfo alloc] initFromPList: value];
				if (info == nil)
					continue;
				
				// Work out what to do with this plugin
				if ([self addUpdatedPlugin: info]) {
					updated = YES;
				}
			}
			
			if (updated) {
				// Notify the delegate of the change
				if (delegate && [delegate respondsToSelector: @selector(pluginInformationChanged)]) {
					[delegate pluginInformationChanged];
				}
			}
		}
		
		// Move on to the next URL
		lastRequest = nil;
		checkConnectionTask = nil;
		checkResponse = nil;
		checkData = nil;
		
		[self startNextCheck];
	}
}

#pragma mark - Installing new plugins

- (void) installPendingPlugins {
	// Work out the list of plugins with pending installations
	NSMutableArray* pendingPlugins = [NSMutableArray array];
	NSEnumerator* pluginEnum = [[self informationForPlugins] objectEnumerator];
	for (ZoomPlugInInfo* info in pluginEnum) {
		if ([info status] == ZoomPlugInDownloaded) {
			[pendingPlugins addObject: info];
		}
	}
	
	// Actually perform the installations
	NSEnumerator* installEnum = [pendingPlugins objectEnumerator];
	for (ZoomPlugInInfo* info in installEnum) {
		// Work out where to install from
		NSString* installPath = nil;
		ZoomDownload* download = [info download];
		
		if (download) {
			// Don't re-use this download
			[info setDownload: nil];
			[info setUpdateInfo: nil];
			
			// Check the download directory for an appropriate bundle
			NSString* downloadDir = [download downloadDirectory];
			
			if (downloadDir != nil) {
				NSEnumerator* downloadDirEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: downloadDir error: NULL] objectEnumerator];
				for (NSString* downloaded in downloadDirEnum) {
					// Need to find a .zoomplugin or .plugin file
					NSString* extension = [[downloaded pathExtension] lowercaseString];
					
					if (![extension isEqualToString: @"plugin"] && ![extension isEqualToString: @"zoomplugin"]) {
						continue;
					}
					
					installPath = [downloadDir stringByAppendingPathComponent: downloaded];
				}
			}
		} else if ([info location] && [[info location] isFileURL]) {
			// Use the info location as the source
			installPath = [[info location] path];
		}
		
		if (!installPath) {
			// Can't install this plugin: don't know where it lives
			NSLog(@"Failed to install plugin: don't know where it lives");
			[info setStatus: ZoomPlugInInstallFailed];
			continue;
		}
		
		// Try to install this plugin
		NSLog(@"== Installing plugin from %@", installPath);
		if (![self installPlugIn: installPath]) {
			NSLog(@"Failed to install plugin");
			[info setStatus: ZoomPlugInInstallFailed];
			continue;
		}
	}
	
	// Ensure any displayed info is up to date
	[self sortInformation];
	[self pluginInformationChanged];
	
	// If a restart is required, inform the delegate
	if (restartRequired) {
		if (delegate && [delegate respondsToSelector: @selector(needsRestart)]) {
			[delegate needsRestart];
		}
	}
}

- (void) downloadNextUpdate {
	// Pick the next plug-in to download an update for
	ZoomPlugInInfo* nextUpdate = nil;
	
	for (ZoomPlugInInfo* info in [self informationForPlugins]) {
		if ([info download] != nil) continue;
		if ([info location] == nil) continue;
		
		if ([info status] == ZoomPlugInNew) {
			nextUpdate = info;
			break;
		}
		if ([info status] == ZoomPluginUpdateAvailable) {
			nextUpdate = info;
			break;
		}
	}
	
	// Finished downloading if we didn't find an update to download
	if (downloading && nextUpdate == nil) {
		// Install any plugins that need installing
		[self installPendingPlugins];
		
		// Finish up, and let the delegate know that we're ready
		currentDownload = nil;
		downloading = NO;
		
		if (delegate && [delegate respondsToSelector: @selector(finishedDownloadingUpdates)]) {
			[delegate finishedDownloadingUpdates];
		}
		return;
	}
	
	// If there's no current download, then notify the delegate that the downloads are starting
	if (!downloading) {
		downloading = YES;
		if (delegate && [delegate respondsToSelector: @selector(downloadingUpdates)]) {
			[delegate downloadingUpdates];
		}
	}
	
	// Start the new download
	currentDownload = nil;
	
	NSURL* url = [nextUpdate location];
	if ([nextUpdate status] == ZoomPluginUpdateAvailable) {
		url = [[nextUpdate updateInfo] location];
	}
	
	currentDownload = [[ZoomDownload alloc] initWithURL: url];
	if (currentDownload == nil) {
		// Couldn't create a download for whatever reason
		[nextUpdate setStatus: ZoomPlugInDownloadFailed];
		[self sortInformation];
		[self pluginInformationChanged];
		[self downloadNextUpdate];
		return;
	}
	
	// Should be an MD5 for this download
	NSData* md5 = [nextUpdate md5];
	if ([nextUpdate status] == ZoomPluginUpdateAvailable) {
		md5 = [[nextUpdate updateInfo] md5];
	}	
	
	if (!md5) {
		NSLog(@"No MD5 specified for a download file: will mark it as failed");
		
		[nextUpdate setStatus: ZoomPlugInDownloadFailed];
		[self sortInformation];
		[self pluginInformationChanged];
		[self downloadNextUpdate];
		return;
	}
	
	[currentDownload setExpectedMD5: md5];
	
	// Start the download running
	[currentDownload setDelegate: self];
	[currentDownload startDownload];
	
	downloadInfo = nextUpdate;
	
	[nextUpdate setDownload: currentDownload];
	[nextUpdate setStatus: ZoomPlugInDownloading];
	[self sortInformation];
	[self pluginInformationChanged];
}

- (void) downloadUpdates {
	if (!currentDownload) {
		[self downloadNextUpdate];		
	}
}

@synthesize restartRequired;

- (BOOL) installPlugIn: (NSString*) pluginBundle {
	// Get the information for the bundle
	ZoomPlugInInfo* bundleInfo = [[ZoomPlugInInfo alloc] initWithBundleFilename: pluginBundle];
	
	// Failed if we can't get the info for the plugin
	if (!bundleInfo) return NO;
	
	// Also failed if we can't get the name for the plugin bundle
	if (![bundleInfo name]) return NO;
	
	// See if we can find an installed plugin that matches this one
	BOOL alreadyInstalled = NO;
	ZoomPlugInInfo* existingPlugIn = nil;

	for (ZoomPlugInInfo* info in [self informationForPlugins]) {
		if ([[info name] isEqualToString: [bundleInfo name]]) {
			if (existingPlugIn == nil) existingPlugIn = info;
			
			if ([info status] == ZoomPlugInInstalled
				|| [info status] == ZoomPlugInUpdated
				|| ([[info location] isFileURL] && ([[[info location] path] hasPrefix: [[NSBundle mainBundle] bundlePath]] || [[[info location] path] hasPrefix: [[self class] plugInsPath]]))) {
				alreadyInstalled = YES;
				existingPlugIn = info;
			}
		}
	}
	
	if (existingPlugIn
		&& [existingPlugIn status] == ZoomPlugInUpdated 
		&& [[existingPlugIn location] isFileURL]) {
		// Remove any existing update for the plugin
		if (![[NSFileManager defaultManager] removeItemAtPath: [[existingPlugIn location] path]
														error: NULL]) {
			return NO;
		}
	}
	
	// Actually install the plugin
	if (alreadyInstalled) {
		// Create the pending plugins directory if needed
		BOOL exists;
		BOOL isDir;
		NSString* pendingPlugIns = [[self class] pendingPlugInsPath]; // [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Pending PlugIns"];
		
		exists = [[NSFileManager defaultManager] fileExistsAtPath: pendingPlugIns
													  isDirectory: &isDir];
		if (exists && !isDir) return NO;
		
		if (!exists) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath: pendingPlugIns
										   withIntermediateDirectories: NO
															attributes: nil
																 error: NULL]) {
				return NO;
			}
		}
		
		NSString* pluginBundlePath = [pendingPlugIns stringByAppendingPathComponent: [pluginBundle lastPathComponent]];
		
		// Delete from the pending directory if the plugin already exists there
		if ([[NSFileManager defaultManager] fileExistsAtPath: pluginBundlePath]) {
			if (![[NSFileManager defaultManager] removeItemAtPath: pluginBundlePath
															error: NULL]) {
				return NO;
			}
		}
		
		// Copy the bundle to the pending directory
		if (![[NSFileManager defaultManager] copyItemAtPath: pluginBundle
													 toPath: pluginBundlePath
													  error: NULL]) {
			return NO;
		}
		
		// Update the previous plugin
		ZoomPlugInInfo* newInfo = [[ZoomPlugInInfo alloc] initWithBundleFilename: pluginBundlePath];
		[newInfo setStatus: ZoomPlugInUpdated];
		restartRequired = YES;
		
		[pluginInformation removeObjectIdenticalTo: existingPlugIn];
		[pluginInformation addObject: newInfo];
	} else {
		// Create the plugins directory if needed
		BOOL exists;
		BOOL isDir;
		NSString* plugins = [[self class] plugInsPath];
		
		if (!plugins) {
			plugins = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns"];			
		}

		exists = [[NSFileManager defaultManager] fileExistsAtPath: plugins
													  isDirectory: &isDir];
		if (exists && !isDir) return NO;
		
		if (!exists) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath: plugins
										   withIntermediateDirectories:NO
															attributes:nil
																 error:NULL]) {
				return NO;
			}
		}
		
		// Copy the bundle to the plugin directory
		if (![[NSFileManager defaultManager] copyItemAtPath: pluginBundle
													 toPath: [plugins stringByAppendingPathComponent: [pluginBundle lastPathComponent]]
													  error: NULL]) {
			return NO;
		}
		
		// Load the new plugin
		NSString* pluginBundlePath = [plugins stringByAppendingPathComponent: [pluginBundle lastPathComponent]];
		[self loadPlugIn: pluginBundlePath];
		
		// Add the information for this plugin
		if (existingPlugIn) {
			[pluginInformation removeObjectIdenticalTo: existingPlugIn];
		}
		
		bundleInfo = [[ZoomPlugInInfo alloc] initWithBundleFilename: pluginBundlePath];
		[bundleInfo setStatus: ZoomPlugInInstalled];
		[pluginInformation addObject: bundleInfo];
	}
	
#if 0
	// Add the file information for this plugin to Zoom's plist file
	NSMutableArray* icons = [NSMutableArray array];
	
	BOOL plistChanged = NO;
	NSString* propertyListPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Info.plist"];
	
	NSMutableDictionary* zoomPlist = [[NSPropertyListSerialization propertyListFromData: [NSData dataWithContentsOfFile: propertyListPath]
																	  mutabilityOption: NSPropertyListMutableContainers
																				format: nil
																	  errorDescription: nil] mutableCopy];
	NSDictionary* pluginPlist = [self plistForBundle: pluginBundle];
	
	if (zoomPlist == nil) {
		NSLog(@"Oops: couldn't get Zoom's plist file");
	}
	if (pluginPlist == nil) {
		NSLog(@"Oops: couldn't get the plist of a new plugin");
	}
	
	// Get the file type information for both plists
	NSMutableArray* zoomFiles = [zoomPlist objectForKey: @"CFBundleDocumentTypes"];
	NSArray* pluginFiles = [pluginPlist objectForKey: @"CFBundleDocumentTypes"];
	
	if (zoomFiles == nil) {
		NSLog(@"Oops: couldn't get document types for the Zoom plist");
	}
	
	if (zoomFiles != nil && pluginFiles != nil) {
		// Iterate through the files in this plugin
		NSEnumerator* fileEnum = [pluginFiles objectEnumerator];
		NSDictionary* fileDict;
		while (fileDict = [fileEnum nextObject]) {
			// Try to find an existing entry for files with the specified extension
			NSEnumerator* existingFileEnum = [zoomFiles objectEnumerator];
			NSDictionary* existingDict;
			BOOL alreadyExists = NO;
			
			while (existingDict = [existingFileEnum nextObject]) {
				NSEnumerator* extnEnum = [[fileDict objectForKey: @"CFBundleTypeExtensions"] objectEnumerator];
				NSString* extn;
				
				while (extn = [extnEnum nextObject]) {
					if ([[existingDict objectForKey: @"CFBundleTypeExtensions"] containsObject: extn]) {
						alreadyExists = YES;
						break;
					}					
				}
				
				if (alreadyExists) break;
			}
			
			// If there is an icon specified then add it to the list of icons to copy into the main resources
			if ([fileDict objectForKey: @"CFBundleTypeIconFile"]) {
				[icons addObject: [fileDict objectForKey: @"CFBundleTypeIconFile"]];
			}
			
			// If there's no matching entry, then add the entry from the plugin
			if (!alreadyExists && [fileDict objectForKey: @"CFBundleTypeExtensions"]) {
				plistChanged = YES;
				restartRequired = YES;
				[zoomFiles addObject: [[fileDict copy] autorelease]];
			}
		}
	}
	
	// Update any UTI entries that are added by the plugin
	NSMutableArray* zoomUti = [zoomPlist objectForKey: @"UTExportedTypeDeclarations"];
	NSArray* pluginUti = [pluginPlist objectForKey: @"UTExportedTypeDeclarations"];
	
	if (zoomUti == nil) {
		NSLog(@"Oops: couldn't get UTI entries for the Zoom plist");
	}
	
	if (zoomUti != nil && pluginUti != nil) {
		NSEnumerator* utiEnum = [pluginUti objectEnumerator];
		NSDictionary* utiDict;
		while (utiDict = [utiEnum nextObject]) {
			// Get the identifier for this UTI entry
			NSString* identifier = [utiDict objectForKey: @"UTTypeIdentifier"];
			if (!identifier) continue;
			BOOL alreadyExists = NO;

			// Work out if this identifier is already in the plist
			NSEnumerator* existingUtiEnum = [zoomUti objectEnumerator];
			NSDictionary* existingUtiDict;
			while (existingUtiDict = [existingUtiEnum nextObject]) {
				if ([identifier isEqual: [existingUtiDict objectForKey: @"UTTypeIdentifier"]]) {
					alreadyExists = YES;
					break;
				}
			}
			
			// If there is no UTI entry for this file, then add the entry from the plugin
			if (!alreadyExists)  {
				plistChanged = YES;
				restartRequired = YES;
				[zoomUti addObject: [[utiDict copy] autorelease]];
			}
		}
	}
	
	// Copy any icon images to the main Zoom resource directory
	NSEnumerator* iconEnum = [icons objectEnumerator];
	NSString* mainBundle = [[NSBundle mainBundle] bundlePath];
	NSString* iconFile;
	while (iconFile = [iconEnum nextObject]) {
		NSString* source = [[[pluginBundle stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Resources"] stringByAppendingPathComponent: iconFile];
		NSString* dest = [[[mainBundle stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Resources"] stringByAppendingPathComponent: iconFile];
		
		if (![[NSFileManager defaultManager] copyItemAtPath: source
													 toPath: dest
													  error: nil]) {
			NSLog(@"Couldn't copy icon file %@ to %@", source, dest);
		}
	}
	
	// Write the new plist
	if (plistChanged) {
		NSData* newPlist = [NSPropertyListSerialization dataFromPropertyList: zoomPlist
																	  format: NSPropertyListXMLFormat_v1_0
															errorDescription: nil];
		if (newPlist) {
			[newPlist writeToFile: propertyListPath
					   atomically: YES];
			restartRequired = YES;
			[bundleInfo setStatus: ZoomPlugInUpdated];
		}
	}

	// Re-register the Zoom application
	if (plistChanged) {
		LSRegisterURL((CFURLRef)[[NSBundle mainBundle] bundleURL], 1);
	}
#endif
	
	// Notify of any changes to the plugin information
	[self sortInformation];
	[self pluginInformationChanged];
	return YES;
}

- (void) finishUpdatingPlugins {
	// Can't finish if we've already loaded the plugins
	if (pluginBundles || pluginClasses) {
		NSLog(@"Oops: can't finish updating plugins as we've already loaded them!");
		return;
	}
	
	// Work out the paths to use
	NSString* plugins = [[self class] plugInsPath];
	NSString* pendingPlugIns = [[self class] pendingPlugInsPath]; // [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Pending PlugIns"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: pendingPlugIns]) {
		return;
	}
	
	if (!plugins) {
		plugins = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns"];			
	}
	
	// Get the set of existing plugins
	NSLog(@"Will finish updating plugins");
	NSMutableDictionary* pluginDictionary = [NSMutableDictionary dictionary];
	
	NSEnumerator* pluginEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: plugins error: NULL] objectEnumerator];
	for (NSString* pluginName in pluginEnum) {
		// Get the information for the next plugin
		NSString* pluginPath = [plugins stringByAppendingPathComponent: pluginName];
		ZoomPlugInInfo* info = [[ZoomPlugInInfo alloc] initWithBundleFilename: pluginPath];
		if (!info) continue;
		
		// File it by the display name
		[pluginDictionary setObject: info
							 forKey: [info name]];
	}
	
	// Replace the old plugins with the new ones
	pluginEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: pendingPlugIns error:NULL] objectEnumerator];
	for (NSString* pluginName in pluginEnum) {
		// Get the information for the next plugin
		NSString* pluginPath = [pendingPlugIns stringByAppendingPathComponent: pluginName];
		ZoomPlugInInfo* info = [[ZoomPlugInInfo alloc] initWithBundleFilename: pluginPath];
		if (!info) {
			NSLog(@"== While updating: %@ is not a valid plugin", pluginName);
			continue;
		}
		
		// Get the old plugin
		ZoomPlugInInfo* oldPlugIn = [pluginDictionary objectForKey: [info name]];
		if (oldPlugIn) {
			if (![oldPlugIn location] || ![[oldPlugIn location] isFileURL]) {
				NSLog(@"== While updating: couldn't locate the plugin to replace for %@", pluginName);
				continue;
			}
			
			// Remove the old plugin
			if (![[NSFileManager defaultManager] removeItemAtPath: [[oldPlugIn location] path]
															error: NULL]) {
				NSLog(@"== While updating: could not delete %@", [oldPlugIn location]);
				continue;
			}
		}
		
		// Copy the new plugin to its final home
		NSString* finalHome = [plugins stringByAppendingPathComponent: pluginName];
		int count = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath: finalHome]) {
			NSLog(@"== While updating: already have a plugin called %@ - picking a new name", [finalHome lastPathComponent]);
			count++;
			finalHome = [plugins stringByAppendingPathComponent: [NSString stringWithFormat: @"%@-%i", pluginName, count]];
		}
		
		if (![[NSFileManager defaultManager] copyItemAtPath: pluginPath
													 toPath: finalHome
													  error: NULL]) {
			NSLog(@"== While updating: could not copy %@ to %@", pluginName, finalHome);
			continue;
		}
	}
	
	// Finish up: delete the pending directory
	if (![[NSFileManager defaultManager] removeItemAtPath: pendingPlugIns
													error: NULL]) {
		NSLog(@"== While updating: could not remove %@", pendingPlugIns);
	}
}

#pragma mark - ZoomDownload delegate functions

- (void) downloadStarting: (ZoomDownload*) download {
	
}

- (void) downloadComplete: (ZoomDownload*) download {
	[downloadInfo setStatus: ZoomPlugInDownloaded];
	[self sortInformation];
	[self pluginInformationChanged];
	[self downloadNextUpdate];	
}

- (void) downloadFailed: (ZoomDownload*) download 
				 reason: (NSString*) reason {
	NSLog(@"Download failed: %@", reason);
	
	[downloadInfo setStatus: ZoomPlugInDownloadFailed];
	[self sortInformation];
	[self pluginInformationChanged];
	[self downloadNextUpdate];
}

- (void) downloadConnecting: (ZoomDownload*) download {
	if (delegate && [delegate respondsToSelector: @selector(downloadProgress:percentage:)]) {
		[delegate downloadProgress: @"Connecting..."
						percentage: -1];		
	}
}

- (void) downloading: (ZoomDownload*) download {
	if (delegate && [delegate respondsToSelector: @selector(downloadProgress:percentage:)]) {
		[delegate downloadProgress: @"Downloading..."
						percentage: -1];		
	}	
}

- (void) download: (ZoomDownload*) download
		completed: (float) complete {
	if (delegate && [delegate respondsToSelector: @selector(downloadProgress:percentage:)]) {
		[delegate downloadProgress: @"Downloading..."
						percentage: complete*100.0];		
	}
}

- (void) downloadUnarchiving: (ZoomDownload*) download {
	if (delegate && [delegate respondsToSelector: @selector(downloadProgress:percentage:)]) {
		[delegate downloadProgress: @"Decompressing..."
						percentage: -1];		
	}	
}

@end
