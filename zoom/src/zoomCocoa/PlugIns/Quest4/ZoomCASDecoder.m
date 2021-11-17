//
//  ZoomCASDecoder.m
//  Quest4
//
//  Created by C.W. Betts on 11/15/21.
//

#import "ZoomCASDecoder.h"

#ifndef __MAC_11_0
#define __MAC_11_0          110000
#endif

#define ARRAY @"", @"game", @"procedure", @"room", @"object", @"character", @"text", @"selection", \
@"define", @"end", @"", @"asl-version", @"game", @"version", @"author", @"copyright", \
@"info", @"start", @"possitems", @"startitems", @"prefix", @"look", @"out", @"gender", \
@"speak", @"take", @"alias", @"place", @"east", @"north", @"west", @"south", @"give", \
@"hideobject", @"hidechar", @"showobject", @"showchar", @"collectable", \
@"collecatbles", @"command", @"use", @"hidden", @"script", @"font", @"default", \
@"fontname", @"fontsize", @"startscript", @"nointro", @"indescription", \
@"description", @"function", @"setvar", @"for", @"error", @"synonyms", @"beforeturn", \
@"afterturn", @"invisible", @"nodebug", @"suffix", @"startin", @"northeast", \
@"northwest", @"southeast", @"southwest", @"items", @"examine", @"detail", @"drop", \
@"everywhere", @"nowhere", @"on", @"anything", @"article", @"gain", @"properties", \
@"type", @"action", @"displaytype", @"override", @"enabled", @"disabled", \
@"variable", @"value", @"display", @"nozero", @"onchange", @"timer", @"alt", @"lib", \
@"up", @"down", @"gametype", @"singleplayer", @"multiplayer", @"", @"", @"", @"", @"", \
@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", \
@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", \
@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"do", @"if", @"got", @"then", @"else", \
@"has", @"say", @"playwav", @"lose", @"msg", @"not", @"playerlose", @"playerwin", \
@"ask", @"goto", @"set", @"show", @"choice", @"choose", @"is", @"setstring", \
@"displaytext", @"exec", @"pause", @"clear", @"debug", @"enter", @"movechar", \
@"moveobject", @"revealchar", @"revealobject", @"concealchar", @"concealobject", \
@"mailto", @"and", @"or", @"outputoff", @"outputon", @"here", @"playmidi", @"drop", \
@"helpmsg", @"helpdisplaytext", @"helpclear", @"helpclose", @"hide", @"show", \
@"move", @"conceal", @"reveal", @"numeric", @"string", @"collectable", @"property", \
@"create", @"exit", @"doaction", @"close", @"each", @"in", @"repeat", @"while", \
@"until", @"timeron", @"timeroff", @"stop", @"panes", @"on", @"off", @"return", \
@"playmod", @"modvolume", @"clone", @"shellexe", @"background", @"foreground", \
@"wait", @"picture", @"nospeak", @"animate", @"persist", @"inc", @"dec", @"flag", \
@"dontprocess", @"destroy", @"beforesave", @"onload", @"", @"", @"", @"", @"", @"", \
@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @""

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_11_0
static NSArray<NSString *> * const compilation_tokens = @[ARRAY];
#else
static NSString * const compilation_tokens[256] =
{
	ARRAY
};
#endif

#undef ARRAY

NSArray<NSString*> *CASDecompile (NSData *dat)
{
	NSMutableString *cur_line = [NSMutableString string];
	NSString *tok;
	int8_t expect_text = 0;
	uint8_t obfus = 0;
	unsigned char ch;
	NSMutableArray *rv = [NSMutableArray array];
	const unsigned char *s = dat.bytes;
	
	
	for (uint i = 8; i < dat.length; i ++) {
		ch = s[i];
		if (obfus == 1 && ch == 0) {
			[cur_line appendString:@"> "];
			obfus = 0;
		} else if (obfus == 1) {
			[cur_line appendFormat:@"%C", (unichar)(char)(255 - ch)];
		} else if (obfus == 2 && ch == 254) {
			obfus = 0;
			[cur_line appendString:@" "];
		} else if (obfus == 2) {
			[cur_line appendFormat:@"%C", (unichar)ch];
		} else if (expect_text == 2) {
			if (ch == 253) {
				expect_text = 0;
				[rv addObject:[cur_line copy]];
				[cur_line setString:@""];
			} else if (ch == 0) {
				[rv addObject:[cur_line copy]];
				[cur_line setString:@""];
			} else {
				[cur_line appendFormat:@"%C", (unichar)(char)(255 - ch)];
			}
		} else if (obfus == 0 && ch == 10) {
			[cur_line appendString: @"<"];
			obfus = 1;
		} else if (obfus == 0 && ch == 254) {
			obfus = 2;
		} else if (ch == 255) {
			if (expect_text == 1)
			{
				expect_text = 2;
			}
			[rv addObject:[cur_line copy]];
			[cur_line setString:@""];
		} else {
			tok = compilation_tokens[ch];
			if (([tok isEqualToString: @"text"] || [tok isEqualToString: @"synonyms"] || [tok isEqualToString: @"type"]) &&
				[cur_line isEqualToString:@"define "]) {
				expect_text = 1;
			}
			[cur_line appendFormat:@"%@ ", tok];
		}
	}
	[rv addObject:[cur_line copy]];
	
	return rv;
}
