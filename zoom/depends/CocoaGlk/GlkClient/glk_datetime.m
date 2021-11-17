/* GlkDateTimeLayer.m: Public API for date and time functions.
	for IosGlk, the iOS implementation of the Glk API.
	Designed by Andrew Plotkin <erkyrath@eblong.com>
	http://eblong.com/zarf/glk/
*/

/*	This file contains the public Glk functions dealing with dates, times, and the real-time clock.
	
	(The "layer" files connect the C-linkable API to the ObjC implementation layer. This is therefore an ObjC file that defines C functions in terms of ObjC method calls. Like all the Glk functions, these must be called from the VM thread, not the main thread.)
*/

#include "glk.h"
#import <Foundation/Foundation.h>
#import "cocoaglk.h"

#ifdef GLK_MODULE_DATETIME
static NSCalendar *getUTCCalendar(void)
{
	static NSCalendar *utccalendar;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		utccalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; // retain
		utccalendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
	});
	return utccalendar;
}

static NSCalendar *getLocalCalendar(void)
{
	static NSCalendar *utccalendar;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		utccalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; // retain
		utccalendar.timeZone = [NSTimeZone localTimeZone];
	});
	return utccalendar;
}


/*! Divide a Unix timestamp by a (positive) value. */
static glsi32 gli_simplify_time(int64_t timestamp, glui32 factor)
{
	/* We want to round towards negative infinity, which takes a little
	   bit of fussing. */
	if (timestamp >= 0) {
		return (glsi32)(timestamp / (time_t)factor);
	}
	else {
		return (glsi32)(-1 - (((time_t)-1 - timestamp) / (time_t)factor));
	}
}

/*! Convert a timestamp value to a Glk time structure. (That is, break it down into 32-bit chunks.)
*/
static void gli_timestamp_to_time(NSTimeInterval timestamp, glktimeval_t *time)
{	
	NSTimeInterval secs = floor(timestamp);
	time->microsec = (glui32)(1000000 * (timestamp - secs));
	int64_t isecs = secs;
	time->high_sec = (isecs >> 32) & 0xFFFFFFFF;
	time->low_sec = isecs & 0xFFFFFFFF;
}

/*! Convert a timestamp value, plus a separate microseconds value, to a Glk time structure. The fractional part of the timestamp is ignored. (This is useful when we already have the microseconds as an integer, and we don't want to divide by 1000000 and then multiply it back up.)
*/
static void gli_timestamp_usec_to_time(NSTimeInterval timestamp, glktimeval_t *time, glsi32 microsec)
{	
	NSTimeInterval secs = floor(timestamp);
	int64_t isecs = secs;
	time->high_sec = (isecs >> 32) & 0xFFFFFFFF;
	time->low_sec = isecs & 0xFFFFFFFF;
	time->microsec = microsec;
}

/*! Convert an NSDate to a Glk date structure, in a given NSCalendar.
*/
static void gli_date_from_time(glkdate_t *date, NSCalendar *nscal, NSDate *nsdate)
{
	NSCalendarUnit comp_units = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond);

	NSDateComponents *comps = [nscal components:comp_units fromDate:nsdate];
	date->year = (glsi32)(comps.year);
	date->month = (glsi32)(comps.month);
	date->day = (glsi32)(comps.day);
	date->weekday = (glsi32)(comps.weekday-1);
	date->hour = (glsi32)(comps.hour);
	date->minute = (glsi32)(comps.minute);
	date->second = (glsi32)(comps.second);
	date->microsec = (glsi32)(comps.nanosecond / 1000);
}

/*! Copy a glkdate to a (newly-created) NSDateComponents structure.
   This is used in the "glk_date_to_..." functions, which are supposed
   to normalize the glkdate.
   
   We skip the weekdate, since it should be ignored by those functions.
*/
static void gli_date_to_comps(glkdate_t *date, NSDateComponents *comps)
{
	comps.year = date->year;
	comps.month = date->month;
	comps.day = date->day;
	comps.hour = date->hour;
	comps.minute = date->minute;
	comps.second = date->second;
	comps.nanosecond = date->microsec * 1000;
}


void glk_current_time(glktimeval_t *time)
{
	NSDate *now = [NSDate date];
	NSTimeInterval timestamp = [now timeIntervalSince1970];
	gli_timestamp_to_time(timestamp, time);
}

glsi32 glk_current_simple_time(glui32 factor)
{
	if (factor == 0) {
		cocoaglk_warning("current_simple_time: factor cannot be zero.");
		return 0;
	}

	NSDate *now = [NSDate date];
	NSTimeInterval timestamp = [now timeIntervalSince1970];
	return gli_simplify_time((int64_t)timestamp, factor);
}

void glk_time_to_date_utc(glktimeval_t *time, glkdate_t *date)
{
	int64_t isec = ((int64_t)time->high_sec << 32) + ((int64_t)time->low_sec);
	NSTimeInterval timestamp = (NSTimeInterval)isec + time->microsec / 1000000.0;
	NSDate *nsdate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	
	NSCalendar *nscal = getUTCCalendar();
	gli_date_from_time(date, nscal, nsdate);
	date->microsec = time->microsec;
}

void glk_time_to_date_local(glktimeval_t *time, glkdate_t *date)
{
	int64_t isec = ((int64_t)time->high_sec << 32) + ((int64_t)time->low_sec);
	NSTimeInterval timestamp = (NSTimeInterval)isec + time->microsec / 1000000.0;
	NSDate *nsdate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	
	NSCalendar *nscal = getLocalCalendar();
	gli_date_from_time(date, nscal, nsdate);
	date->microsec = time->microsec;
}

void glk_simple_time_to_date_utc(glsi32 time, glui32 factor, glkdate_t *date)
{
	int64_t isec = (int64_t)time * factor;
	NSTimeInterval timestamp = (NSTimeInterval)isec;
	NSDate *nsdate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	
	NSCalendar *nscal = getUTCCalendar();
	gli_date_from_time(date, nscal, nsdate);
	date->microsec = 0;
}

void glk_simple_time_to_date_local(glsi32 time, glui32 factor, glkdate_t *date)
{
	int64_t isec = (int64_t)time * factor;
	NSTimeInterval timestamp = (NSTimeInterval)isec;
	NSDate *nsdate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	
	NSCalendar *nscal = getLocalCalendar();
	gli_date_from_time(date, nscal, nsdate);
	date->microsec = 0;
}

void glk_date_to_time_utc(glkdate_t *date, glktimeval_t *time)
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	gli_date_to_comps(date, comps);
	glsi32 microsec = (glsi32)(comps.nanosecond / 1000);
	
	NSCalendar *nscal = getUTCCalendar();
	NSDate *nsdate = [nscal dateFromComponents:comps];
	if (!nsdate) {
		time->high_sec = -1;
		time->low_sec = -1;
		time->microsec = -1;
		return;
	}
	
	NSTimeInterval timestamp = [nsdate timeIntervalSince1970];
	gli_timestamp_usec_to_time(timestamp, time, microsec);
}

void glk_date_to_time_local(glkdate_t *date, glktimeval_t *time)
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	gli_date_to_comps(date, comps);
	glsi32 microsec = (glsi32)(comps.nanosecond / 1000);
	
	NSCalendar *nscal = getLocalCalendar();
	NSDate *nsdate = [nscal dateFromComponents:comps];
	if (!nsdate) {
		time->high_sec = -1;
		time->low_sec = -1;
		time->microsec = -1;
		return;
	}
	
	NSTimeInterval timestamp = [nsdate timeIntervalSince1970];
	gli_timestamp_usec_to_time(timestamp, time, microsec);
}

glsi32 glk_date_to_simple_time_utc(glkdate_t *date, glui32 factor)
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	gli_date_to_comps(date, comps);
	
	NSCalendar *nscal = getUTCCalendar();
	NSDate *nsdate = [nscal dateFromComponents:comps];
	if (!nsdate) {
		return -1;
	}

	NSTimeInterval timestamp = [nsdate timeIntervalSince1970]; // drop microseconds
	return gli_simplify_time((int64_t)timestamp, factor);
}

glsi32 glk_date_to_simple_time_local(glkdate_t *date, glui32 factor)
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	gli_date_to_comps(date, comps);
	
	NSCalendar *nscal = getLocalCalendar();
	NSDate *nsdate = [nscal dateFromComponents:comps];
	if (!nsdate) {
		return -1;
	}

	NSTimeInterval timestamp = [nsdate timeIntervalSince1970]; // drop microseconds
	return gli_simplify_time((int64_t)timestamp, factor);
}

#endif
