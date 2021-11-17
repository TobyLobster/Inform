//
//  MetadataImporter.m
//  ZoomCocoa
//
//  Created by Collin Pieper on 9/4/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "MetadataImporter.h"

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFPlugInCOM.h>
#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

#import <ZoomPlugIns/ifmetabase.h>

#import <ZoomPlugIns/ZoomMetadata.h>
#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

// -----------------------------------------------------------------------------
//	protos
// -----------------------------------------------------------------------------

static ZoomStory * FindStory( ZoomStoryID * gameID );
static NSString * GetZoomConfigDirectory( void );
static NSArray<ZoomMetadata*> * GetGameIndices( void );

// -----------------------------------------------------------------------------
//	constants
// -----------------------------------------------------------------------------

// Step 1. Generate a unique UUID for your importer
//
// You can obtain a UUID by running uuidgen in Terminal.  The
// uuidgen program prints a string representation of a 128-bit
// number.
//
// Below, replace "MetadataImporter_PLUGIN_ID" with the string
// printed by uuidgen.

#define PLUGIN_ID "456EF067-FF4A-4F3B-9BD1-F58545340FCE"

// Step 2. Set the plugin ID in Info.plist
//
// Replace the occurrances of MetadataImporter_PLUGIN_ID
// in Info.plist with the string Representation of your GUUID

// Step 3. Set the UTI types the importer supports
//
// Modify the CFBundleDocumentTypes entry in Info.plist to contain
// an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes
// that your importer can handle

// Optional:
// Step 4. If you are defining new attributes, update the schema.xml file
//
// Edit the schema.xml file to include the metadata keys that your importer returns.
// Add them to the <allattrs> and <displayattrs> elements.
//
// Add any custom types that your importer requires to the <attributes> element
//
// <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>

// Step 5. Implement the GetMetadataForFile function as requires by your document

// -----------------------------------------------------------------------------
//	Get metadata attributes from file
//
// This function's job is to extract useful information your file format supports
// and return it as a dictionary
// -----------------------------------------------------------------------------

static Boolean GetMetadataForFile(void *thisInterface,
			   CFMutableDictionaryRef attributes,
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
	@autoreleasepool {
		ZoomIsSpotlightIndexing = YES;
		NSMutableDictionary *nsAttribs = (__bridge NSMutableDictionary *)(attributes);
	/* Pull any available metadata from the file at the specified path */
	/* Return the attribute keys and attribute values in the dict */
	/* Return TRUE if successful, FALSE if there was no data provided */

    Boolean success = NO;

	// Get the story from the metadata database
		ZoomStoryID * story_id = [[ZoomStoryID alloc] initWithZCodeFileAtURL: [NSURL fileURLWithPath: (__bridge NSString*)pathToFile] error: NULL];
	ZoomStory * story = FindStory( story_id );
		if (!story) {
			return NO;
		}

//	NSLog( @"story_id = 0x%08lx story = 0x%08lx path = %@\n", story_id, story, pathToFile );
	
	//////////////////////////////////////////////////////

	//
	// title
	//
	
	NSString * title = [story title];
	if( title )
	{
		[nsAttribs setObject:title forKey:(NSString *)kMDItemTitle];
	}

	//
	// headline
	//
	
	NSString * headline = [story headline];
	if( headline )
	{
		[nsAttribs setObject:headline forKey:(NSString *)kMDItemHeadline];
	}
	
	//
	// author
	//
	
	NSString * author = [story author];
	if( author )
	{
		[nsAttribs setObject:@[author] forKey:(NSString *)kMDItemAuthors];
	}

	//
	// genre
	//
	
	NSString * genre = [story genre];
	if( genre )
	{
		[nsAttribs setObject:genre forKey:@"public_zcode_genre"];
	}

	//
	// year
	//
	
	
	int year = [story year];
	if( year )
	{
		NSNumber * year_object = @(year);
		[nsAttribs setObject:year_object forKey:@"public_zcode_year"];
	}
	
	//
	// group
	//
	
	NSString * group = [story group];
	if( group )
	{
		[nsAttribs setObject:group forKey:(NSString *)@"public_zcode_group"];
	}

	//
	// zarf rating
	//
	
	unsigned zarfian = [story zarfian];
	NSString * zarf_string = nil;
	switch( zarfian ) 
	{
		case IFMD_Merciful: 
			zarf_string = @"Merciful";
			break;
			
		case IFMD_Polite: 
			zarf_string = @"Polite";
			break;
			
		case IFMD_Tough:
			zarf_string = @"Tough";
			break;
			
		case IFMD_Nasty:
			zarf_string = @"Nasty";
			break;
			
		case IFMD_Cruel:
			zarf_string = @"Cruel";
			break;
		
		case IFMD_Unrated:	
		default: 
			break;
	}
	
	if( zarf_string )
	{
		[nsAttribs setObject:zarf_string forKey:@"public_zcode_cruelty"];
	}

	//
	// teaser
	//
	
	NSString * teaser = [story teaser];
	if( teaser )
	{
		[nsAttribs setObject:teaser forKey:@"public_zcode_teaser"];
	}

	//
	// comment
	//
	
	NSString * comment = [story comment];
	if( comment )
	{
		[nsAttribs setObject:comment forKey:(NSString *)kMDItemComment];
	}

	//
	// rating
	//
	
	float rating = [story rating];
	if( rating != -1.0 )
	{
		NSNumber * rating_object = @(rating);
		[nsAttribs setObject:rating_object forKey:(NSString *)kMDItemStarRating];
	}

	//
	// keywords
	//
	
//	NSArray * keywords = @[@"Zoom", @"Z-Machine", @"ZMachine", @"Interactive Fiction", @"IF",
//							@"ZCode", @"Z-Code", @"Text Adventure", @"Text Adventures", @"Adventure Game", 
//							@"Adventure Games", @"Text Game", @"Text Games", @"Game", @"Games"];	
//	if( keywords )
//	{
//		[nsAttribs setObject:keywords forKey:(NSString *)kMDItemKeywords];
//	}
	
	// return YES so that the attributes are imported
	success=YES;
		
	return success;
	}
}

// FindStory
//
//

ZoomStory * FindStory( ZoomStoryID * gameID ) 
{
	ZoomStory * story = nil;
	
	NSArray * game_indices = GetGameIndices();

	for (ZoomMetadata * repository in game_indices) {
		story = [repository containsStoryWithIdent: gameID]?[repository findOrCreateStory:gameID]:nil;
		if( story ) 
			break;
	}
	
	return story;
}

// GetGameIndices
//
//

NSArray * GetGameIndices( void )
{
	static NSMutableArray * game_indices = nil;
	
	if (game_indices == nil) {
		game_indices = [[NSMutableArray alloc] init];

		NSString * config_dir = GetZoomConfigDirectory();
	//	NSLog( @"config_dir = %@\n", config_dir );
		
		NSData * userData = [NSData dataWithContentsOfFile:[config_dir stringByAppendingPathComponent: @"metadata.iFiction"]];

		NSBundle * bundle = [NSBundle bundleWithIdentifier:@"uk.org.logicalshift.ZoomMetadataImporter"];
		
	//	NSLog( @"bundlePath = %@\n", [bundle bundlePath] );
		
		NSData * infocomData = [NSData dataWithContentsOfFile:[bundle pathForResource: @"infocom" ofType: @"iFiction"]];
		NSData * archiveData = [NSData dataWithContentsOfFile:[bundle pathForResource: @"archive" ofType: @"iFiction"]];

	//	NSLog( @"userData = 0x%08lx infocomData = 0x%08lx archiveData = 0x%08lx\n", userData, infocomData, archiveData );
		
		if( userData ) 
		{
			[game_indices addObject:[[ZoomMetadata alloc] initWithData:userData]];
		}
		else
		{
			[game_indices addObject:[[ZoomMetadata alloc] init]];
		}
		
		if( infocomData ) 
		{
			[game_indices addObject:[[ZoomMetadata alloc] initWithData: infocomData]];
		}
		
		if( archiveData ) 
		{
			[game_indices addObject:[[ZoomMetadata alloc] initWithData: archiveData]];
		}
	}
	
	return game_indices;
}

// GetZoomConfigDirectory
//
//

NSString * GetZoomConfigDirectory( void )
{
	NSArray * library_directories = NSSearchPathForDirectoriesInDomains( NSLibraryDirectory, NSUserDomainMask, YES );

	for ( NSString * directory in library_directories )
	{
		BOOL is_directory;
		
		NSString * zoom_library = [[directory stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:zoom_library isDirectory:&is_directory] ) 
		{
			if( is_directory ) 
			{
				return zoom_library;
			}
		}
	}

#if 0
	// the md importer doesn't need to be creating directories
	
	libEnum = [libraryDirs objectEnumerator];
	
	while( libDir = [libEnum nextObject] )
	{
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if( [[NSFileManager defaultManager] createDirectoryAtPath:zoomLib attributes:nil] ) 
		{
			return zoomLib;
		}
	}
#endif
	
	return nil;
}
//
// Below is the generic glue code for all plug-ins.
//
// You should not have to modify this code aside from changing
// names if you decide to change the names defined in the Info.plist
//

// -----------------------------------------------------------------------------
//	typedefs
// -----------------------------------------------------------------------------

// The layout for an instance of MetaDataImporterPlugIn
typedef struct __MetadataImporterPluginType
{
    MDImporterInterfaceStruct *	conduitInterface;
    CFUUIDRef					factoryID;
    UInt32						refCount;
} MetadataImporterPluginType;

// -----------------------------------------------------------------------------
//	prototypes
// -----------------------------------------------------------------------------
//	Forward declaration for the IUnknown implementation.
//

static MetadataImporterPluginType *	AllocMetadataImporterPluginType( CFUUIDRef inFactoryID );
static void							DeallocMetadataImporterPluginType( MetadataImporterPluginType * thisInstance );
static HRESULT						MetadataImporterQueryInterface( void * thisInstance, REFIID iid, LPVOID * ppv );
extern void *						MetadataImporterPluginFactory( CFAllocatorRef allocator, CFUUIDRef typeID );
static ULONG						MetadataImporterPluginAddRef( void * thisInstance );
static ULONG						MetadataImporterPluginRelease( void * thisInstance );

// -----------------------------------------------------------------------------
//	testInterfaceFtbl	definition
// -----------------------------------------------------------------------------
//	The TestInterface function table.
//

static MDImporterInterfaceStruct testInterfaceFtbl = 
{
    NULL,
    MetadataImporterQueryInterface,
    MetadataImporterPluginAddRef,
    MetadataImporterPluginRelease,
    GetMetadataForFile
};

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

// -----------------------------------------------------------------------------
//	AllocMetadataImporterPluginType
// -----------------------------------------------------------------------------
//	Utility function that allocates a new instance.
//      You can do some initial setup for the importer here if you wish
//      like allocating globals etc...
//

MetadataImporterPluginType * AllocMetadataImporterPluginType( CFUUIDRef inFactoryID )
{
    MetadataImporterPluginType *theNewInstance;

    theNewInstance = (MetadataImporterPluginType *)malloc( sizeof(MetadataImporterPluginType) );
    memset( theNewInstance, 0, sizeof(MetadataImporterPluginType) );

	// Point to the function table
    theNewInstance->conduitInterface = &testInterfaceFtbl;

    //  Retain and keep an open instance refcount for each factory.
    theNewInstance->factoryID = CFRetain( inFactoryID );
    CFPlugInAddInstanceForFactory( inFactoryID );

    // This function returns the IUnknown interface so set the refCount to one.
    theNewInstance->refCount = 1;
	
    return theNewInstance;
}

// -----------------------------------------------------------------------------
//	DeallocMetadataImporterPluginType
// -----------------------------------------------------------------------------
//	Utility function that deallocates the instance when
//	the refCount goes to zero.
//      In the current implementation importer interfaces are never deallocated
//      but implement this as this might change in the future
//

void DeallocMetadataImporterPluginType( MetadataImporterPluginType * thisInstance )
{
    CFUUIDRef theFactoryID;

    theFactoryID = thisInstance->factoryID;
    free( thisInstance );
    if( theFactoryID )
	{
        CFPlugInRemoveInstanceForFactory( theFactoryID );
        CFRelease( theFactoryID );
    }
}

// -----------------------------------------------------------------------------
//	MetadataImporterQueryInterface
// -----------------------------------------------------------------------------
//	Implementation of the IUnknown QueryInterface function.
//

HRESULT MetadataImporterQueryInterface( void * thisInstance, REFIID iid, LPVOID *ppv )
{
    CFUUIDRef interfaceID;

    interfaceID = CFUUIDCreateFromUUIDBytes( kCFAllocatorDefault, iid );

    if( CFEqual( interfaceID, kMDImporterInterfaceID ) )
	{
		// If the Right interface was requested, bump the ref count,
		// set the ppv parameter equal to the instance, and
		// return good status.
		//

        ((MetadataImporterPluginType*)thisInstance)->conduitInterface->AddRef( thisInstance );
        *ppv = thisInstance;
        CFRelease( interfaceID );

        return S_OK;
    }
	else if( CFEqual( interfaceID, IUnknownUUID ) )
	{
		// If the IUnknown interface was requested, same as above.
		((MetadataImporterPluginType*)thisInstance )->conduitInterface->AddRef( thisInstance );
		*ppv = thisInstance;
		CFRelease( interfaceID );
		
		return S_OK;
	}
	else
	{
		// Requested interface unknown, bail with error.
		*ppv = NULL;
		CFRelease( interfaceID );
		
		return E_NOINTERFACE;
	}
}

// -----------------------------------------------------------------------------
//	MetadataImporterPluginAddRef
// -----------------------------------------------------------------------------
//	Implementation of reference counting for this type. Whenever an interface
//	is requested, bump the refCount for the instance. NOTE: returning the
//	refcount is a convention but is not required so don't rely on it.
//

ULONG MetadataImporterPluginAddRef( void *thisInstance )
{
    ((MetadataImporterPluginType *)thisInstance )->refCount += 1;

    return ((MetadataImporterPluginType*) thisInstance)->refCount;
}

// -----------------------------------------------------------------------------
// MetadataImporterPluginRelease
// -----------------------------------------------------------------------------
//	When an interface is released, decrement the refCount.
//	If the refCount goes to zero, deallocate the instance.
//

ULONG MetadataImporterPluginRelease( void * thisInstance )
{
    ((MetadataImporterPluginType*)thisInstance)->refCount -= 1;

    if( ((MetadataImporterPluginType*)thisInstance)->refCount == 0 )
	{
        DeallocMetadataImporterPluginType( (MetadataImporterPluginType*)thisInstance );
        return 0;
    }
	else
	{
        return ((MetadataImporterPluginType*) thisInstance )->refCount;
    }
}

// -----------------------------------------------------------------------------
//	MetadataImporterPluginFactory
// -----------------------------------------------------------------------------
//	Implementation of the factory function for this type.
//

void * MetadataImporterPluginFactory( CFAllocatorRef allocator, CFUUIDRef typeID )
{
    MetadataImporterPluginType *	result;
    CFUUIDRef						uuid;

	// If correct type is being requested, allocate an
	// instance of TestType and return the IUnknown interface.
	//
	 
    if( CFEqual(typeID,kMDImporterTypeID) )
	{
        uuid = CFUUIDCreateFromString( kCFAllocatorDefault, CFSTR(PLUGIN_ID) );
        result = AllocMetadataImporterPluginType( uuid );
        CFRelease( uuid );
    
		return result;
    }
	
	// If the requested type is incorrect, return NULL.
	
	return NULL;
}
