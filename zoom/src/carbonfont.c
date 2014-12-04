/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Fonts for Mac OS (Carbon)
 *
 * There are no less than three different font drivers here:
 *   - QuickDraw Text
 *   - ATSUI
 *   - Quartz
 *
 * ATSUI is slow, and to use it properly you'd really need to rewrite
 * the whole rendering interface. That's probably not worth it...
 * (Well, it would make copy/paste a bit easier to implement
 *
 * QuickDraw uses a crappy font rendering engine
 *
 * Quartz looks nice, but there is a shortage of ways of measuring text:
 * the way we do it is a bit of a hack, but seems accurate enough.
 * (You can't define USE_QUARTZ and USE_ATS...)
 *
 * All this is why this file is a bit of a mess in places...
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#include <stdlib.h>
#include <string.h>

#include <Carbon/Carbon.h>

#include "zmachine.h"
#include "rc.h"
#include "font3.h"
#include "xfont.h"
#include "carbondisplay.h"

extern XFONT_MEASURE xfont_x;
extern XFONT_MEASURE xfont_y;

static PolyHandle f3[96];

struct xfont
{
  enum
    {
      FONT_INTERNAL,
      FONT_FONT3
    } type;
  union
  {
    struct
    {
#ifdef USE_ATS
      FMFontFamily family;
      ATSUFontID font;
      ATSUStyle  style;
#else
      FMFontFamily family;
      int size;
      int isbold;
      int isitalic;
      int isunderlined;

      TextEncoding      encoding;
      UnicodeToTextInfo convert;

# ifdef USE_QUARTZ
      ATSFontRef atsref;
      ATSUStyle  style;
      char*      psname;
      CGFontRef  cgfont;
# endif

#endif

      XFONT_MEASURE ascent, descent, maxwidth;
    } mac;
  } data;
};

static RGBColor fg_col, bg_col;
static int transpar = 0;

#ifdef USE_QUARTZ
CGContextRef carbon_quartz_context = nil;

static xfont*       winlastfont = NULL;
static int          enable_quartz = 0;
#endif

/***                           ----// 888 \\----                           ***/

#ifdef USE_QUARTZ
void carbon_set_context(void)
{
  CGrafPtr thePort = GetQDGlobalsThePort();

  CGContextRelease(carbon_quartz_context);
  CreateCGContextForPort(thePort, &carbon_quartz_context);
  winlastfont = NULL;

  if (rc_get_antialias())
    {
      CGContextSetShouldAntialias(carbon_quartz_context,
				  1);
    }
  else
    {
      CGContextSetShouldAntialias(carbon_quartz_context,
				  0);
    }
}

void carbon_set_quartz(int q)
{
  enable_quartz = q;
}
#endif

static double scale_factor = 1.0;

void carbon_set_scale_factor(double factor)
{
  scale_factor = factor;
}

void xfont_initialise(void)
{
  int x;

#ifdef USE_QUARTZ
  if (carbon_quartz_context == nil)
    {
      CGrafPtr p;
      OSStatus res;
      
      p = GetWindowPort(zoomWindow);

      res = CreateCGContextForPort(p, &carbon_quartz_context);
      
      winlastfont = NULL;
    }
#endif

  for (x=0; x<96; x++)
    f3[x] = nil;
}

void xfont_shutdown(void)
{
}

#ifndef USE_ATS
static void select_font(xfont* font)
{
  TextFont(font->data.mac.family);
  TextSize(font->data.mac.size);
  TextFace((font->data.mac.isbold?bold:0)           |
	   (font->data.mac.isitalic?italic:0)       |
	   (font->data.mac.isunderlined?underline:0));
}
#endif

#define DEFAULT_FONT applFont


/*
 * Internal format for Mac OS font names
 *
 * "face name" width properties
 *
 * Where properties can be one or more of:
 *   b - bold
 *   i - italic
 *   u - underline
 */
static xfont* xfont_default_font(void)
{
  xfont* xf;

#ifdef USE_ATS
  return NULL;
#else
  xf = malloc(sizeof(struct xfont));
  xf->type = FONT_INTERNAL;
  xf->data.mac.family       = DEFAULT_FONT;
  xf->data.mac.size         = 12;
  xf->data.mac.isbold       = 0;
  xf->data.mac.isitalic     = 0;
  xf->data.mac.isunderlined = 0;
  return xf;
#endif
}

carbon_font* carbon_parse_font(char* font)
{
  int x;

  static carbon_font fnt;
  char*       face_name;
  static char fontcopy[256];
  char*       face_width;
  char*       face_props;

  if (strcmp(font, "font3") == 0)
    {
      fnt.isfont3 = 1;
      fnt.isbold = fnt.isitalic = fnt.isunderlined = 0;
      fnt.size = 0;
      return &fnt;
    }
  fnt.isfont3 = 0;

  if (strlen(font) > 256)
    {
      zmachine_warning("Invalid font name (too long)");
 
      return NULL;
    }

  /* Get the face name */
  strcpy(fontcopy, font);
  x = 0;
  while (fontcopy[x++] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (font name must be in single quotes)", font);

	  return NULL;
	}
    }

  face_name = &fontcopy[x];

  x--;
  while (fontcopy[++x] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (missing \')", font);

	  return NULL;
	}
    }
  fontcopy[x] = 0;

  /* Get the font width */
  while (fontcopy[++x] == ' ')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (no font size specified)", font);

	  return NULL;
	}
    }

  face_width = &fontcopy[x];

  while (fontcopy[x] >= '0' &&
	 fontcopy[x] <= '9')
    x++;

  if (fontcopy[x] != ' ' &&
      fontcopy[x] != 0)
    {
      zmachine_warning("Invalid font name: %s (invalid size)", font);

      return NULL;
    }

  if (fontcopy[x] != 0)
    {
      fontcopy[x] = 0;
      face_props  = &fontcopy[x+1];
    }
  else
    face_props = NULL;

  fnt.face_name = face_name;
  fnt.size = atoi(face_width);
  fnt.isbold = fnt.isitalic = fnt.isunderlined = 0;

  if (face_props != NULL)
    {
      for (x=0; face_props[x] != 0; x++)
	{
	  switch (face_props[x])
	    {
	    case 'b':
	    case 'B':
	      fnt.isbold = 1;
	      break;

	    case 'i':
	    case 'I':
	      fnt.isitalic = 1;
	      break;

	    case 'u':
	    case 'U':
	      fnt.isunderlined = 1;
	      break;
	    }
	}
    }

  return &fnt;
}

xfont* xfont_load_font(char* font)
{
  char   fontcopy[256];
  char*  face_name;
  Str255 family;
  char*  face_width;
  char*  face_props;
  xfont* xf;

  int x;

  GrafPtr oldport;
  FontInfo fm;
  int aspace[] = { 'T', 'e', 's', 't' };

#ifdef USE_ATS
  OSStatus erm;

  ATSUAttributeTag tags[3] = 
    { 
      kATSUSizeTag, kATSUQDUnderlineTag,
      kATSUFontTag 
    };
  ByteCount             attsz [3];
  ATSUAttributeValuePtr attptr[3];

  Fixed size;
  Boolean isbold, isitalic, isunderline;
#endif

  if (strcmp(font, "font3") == 0)
    {
      xf = malloc(sizeof(struct xfont));

      xf->type = FONT_FONT3;

      return xf;
    }
  
  if (strlen(font) > 256)
    {
      zmachine_warning("Invalid font name (too long)");
 
      return xfont_default_font();
    }

  /* Get the face name */
  strcpy(fontcopy, font);
  x = 0;
  while (fontcopy[x++] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (font name must be in single quotes)", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }

  face_name = &fontcopy[x];

  x--;
  while (fontcopy[++x] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (missing \')", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }
  fontcopy[x] = 0;

  /* Get the font width */
  while (fontcopy[++x] == ' ')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (no font size specified)", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }

  face_width = &fontcopy[x];

  while (fontcopy[x] >= '0' &&
	 fontcopy[x] <= '9')
    x++;

  if (fontcopy[x] != ' ' &&
      fontcopy[x] != 0)
    {
      zmachine_warning("Invalid font name: %s (invalid size)", font);

      xf = xfont_default_font();
      return xf;
    }

  if (fontcopy[x] != 0)
    {
      fontcopy[x] = 0;
      face_props  = &fontcopy[x+1];
    }
  else
    face_props = NULL;

  xf = malloc(sizeof(xfont));

#ifdef USE_ATS
  /* Locate the font */
  xf->type = FONT_INTERNAL;
  isbold = isitalic = isunderline = false;
  
  if (face_props != NULL)
    {
      for (x=0; face_props[x] != 0; x++)
	{
	  switch (face_props[x])
	    {
	    case 'b':
	    case 'B':
	      isbold = true;
	      break;

	    case 'i':
	    case 'I':
	      isitalic = true;
	      break;

	    case 'u':
	    case 'U':
	      isunderline = true;
	      break;
	    }
	}
    }

  family[0] = strlen(face_name);
  strcpy(family+1, face_name);
  xf->data.mac.family = FMGetFontFamilyFromName(family);
  erm = FMGetFontFromFontFamilyInstance(xf->data.mac.family,
					(isbold?bold:0)           |
					(isitalic?italic:0)       |
					(isunderline?underline:0),
					&xf->data.mac.font,
					NULL);

  if (erm != noErr)
    {
      zmachine_warning("Font family '%s' not found", face_name);
      free(xf);
      return xfont_default_font();
    }

  ATSUCreateStyle(&xf->data.mac.style);
  
  size = atoi(face_width)<<16;
  size = (int) ((double)size * scale_factor);

  /* Set the attributes of this font */
  attsz[0] = sizeof(Fixed);
  attsz[1] = sizeof(Boolean);
  attsz[2] = sizeof(ATSUFontID);
  attptr[0] = &size;
  attptr[1] = &isunderline;
  attptr[2] = &xf->data.mac.font;

  ATSUSetAttributes(xf->data.mac.style, 3, tags, attsz, attptr);

  /* Measure the font */
  {
    ATSUTextLayout lo;
    UniChar text[1] = { 'M' };

    ATSUTextMeasurement before, after, ascent, descent;

    /* 
     * (Sigh, there has to be a better way of doing things... We really just 
     * want the metrics)
     */

    ATSUCreateTextLayout(&lo);
    ATSUSetTextPointerLocation(lo, text, 0, 1, 1);
    ATSUSetRunStyle(lo, xf->data.mac.style, 0, 1);
    ATSUMeasureText(lo, 0, 1, &before, &after, &ascent, &descent);
    
    xf->data.mac.ascent = ascent/65536.0;
    xf->data.mac.descent = descent/65536.0;
    xf->data.mac.maxwidth = (after+before)/65536.0;

    ATSUDisposeTextLayout(lo);
  }
#else

  xf->type = FONT_INTERNAL;
  family[0] = strlen(face_name);
  strcpy(family+1, face_name);
  xf->data.mac.family = FMGetFontFamilyFromName(family);
  if (xf->data.mac.family == kInvalidFontFamily)
    {
      zmachine_warning("Font '%s' not found, reverting to default", face_name);
      xf->data.mac.family = DEFAULT_FONT;
    }
  xf->data.mac.size = (int)((double)atoi(face_width)*scale_factor);
  xf->data.mac.isbold = 0;  
  xf->data.mac.isitalic = 0;
  xf->data.mac.isunderlined = 0;

  if (face_props != NULL)
    {
      for (x=0; face_props[x] != 0; x++)
	{
	  switch (face_props[x])
	    {
	    case 'b':
	    case 'B':
	      xf->data.mac.isbold = 1;
	      break;

	    case 'i':
	    case 'I':
	      xf->data.mac.isitalic = 1;
	      break;

	    case 'u':
	    case 'U':
	      xf->data.mac.isunderlined = 1;
	      break;
	    }
	}
    }

  if (FMGetFontFamilyTextEncoding(xf->data.mac.family, &xf->data.mac.encoding)
      != noErr)
    zmachine_fatal("Unable to get encoding for font '%s'", face_name);
  if (CreateUnicodeToTextInfoByEncoding(xf->data.mac.encoding, &xf->data.mac.convert)
      != noErr)
    zmachine_fatal("Unable to create TextInfo structure for font '%s'", face_name);

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  GetFontInfo(&fm);

# ifdef USE_QUARTZ
  {
    FMFont font;
    OSStatus erm;

    erm = FMGetFontFromFontFamilyInstance(xf->data.mac.family,
					  (xf->data.mac.isbold?bold:0)           |
					  (xf->data.mac.isitalic?italic:0)       |
					  (xf->data.mac.isunderlined?underline:0),
					  &font,
					  NULL);

    if (erm != noErr)
      zmachine_fatal("Unable to get FMFont structure for font '%s'", face_name);

    xf->data.mac.atsref = FMGetATSFontRefFromFont(font);
    xf->data.mac.cgfont = CGFontCreateWithPlatformFont(&xf->data.mac.atsref);
    {
      CFStringRef str;
      char buf[256];

      ATSUAttributeTag tags[5] =
	{ 
	  kATSUSizeTag, kATSUQDBoldfaceTag, 
	  kATSUQDItalicTag, kATSUQDUnderlineTag,
	  kATSUFontTag 
	};
      ByteCount             attsz [5];
      ATSUAttributeValuePtr attptr[5];

      ATSUFontFeatureType fe_types[] = { kLigaturesType };
      ATSUFontFeatureSelector fe_sel[] = { kCommonLigaturesOffSelector };

      /* Get the name of this font */
      ATSFontGetPostScriptName(xf->data.mac.atsref,
			       0,
			       &str);
      CFStringGetCString(str, buf, 256, kCFStringEncodingMacRoman);
      
      xf->data.mac.psname = malloc(strlen(buf)+1);
      strcpy(xf->data.mac.psname, buf);
      CFRelease(str);

      /* 
       * Create an ATSU style (bleh, we need to do this so we can work out 
       * the glyph IDs to plot) 
       */
      ATSUCreateStyle(&xf->data.mac.style);

      attsz[1] = attsz[2] = attsz[3] = sizeof(Boolean);
      attsz[4] = sizeof(ATSUFontID);
      attptr[0] = &xf->data.mac.size;
      attptr[1] = &xf->data.mac.isbold;
      attptr[2] = &xf->data.mac.isitalic;
      attptr[3] = &xf->data.mac.isunderlined;
      attptr[4] = &xf->data.mac.atsref;

      ATSUSetAttributes(xf->data.mac.style, 4, tags+1, attsz+1, attptr+1);

      ATSUSetFontFeatures(xf->data.mac.style, 1, fe_types, fe_sel);
    }
  }
# endif

  xf->data.mac.ascent   = fm.ascent;
  xf->data.mac.descent  = fm.descent + fm.leading;
  xf->data.mac.maxwidth = xfont_get_text_width(xf, aspace, 4)/4.0;

  SetPort(oldport);
#endif

  return xf;
}

void xfont_release_font(xfont* xf)
{
  if (xf->type != FONT_FONT3)
    {
#ifdef USE_ATS
      ATSUDisposeStyle(xf->data.mac.style);
#else
      DisposeUnicodeToTextInfo(&xf->data.mac.convert);
# ifdef USE_QUARTZ
      CGFontRelease(xf->data.mac.cgfont);
      ATSUDisposeStyle(xf->data.mac.style);
      free(xf->data.mac.psname);
# endif
#endif
    }
  free(xf);
}

void xfont_set_colours(int fg, int bg)
{
  fg_col = *carbon_get_colour(fg);

  transpar = 0;
  if (bg >= 0)
    bg_col = *carbon_get_colour(bg);
  else
    transpar = 1;
}

XFONT_MEASURE xfont_get_height(xfont* xf)
{
  if (xf->type == FONT_FONT3)
    return xfont_y;

  return xf->data.mac.ascent + xf->data.mac.descent;
}

XFONT_MEASURE xfont_get_ascent(xfont* xf)
{
  if (xf->type == FONT_FONT3)
    return xfont_y;

  return xf->data.mac.ascent;
}

XFONT_MEASURE xfont_get_descent(xfont* xf)
{
  if (xf->type == FONT_FONT3)
    return 0;

  return xf->data.mac.descent;
}

XFONT_MEASURE xfont_get_width(xfont* xf)
{
  if (xf->type == FONT_FONT3)
    return xfont_x;

  return xf->data.mac.maxwidth;
}

#ifndef USE_ATS
static char* convert_text(xfont* font,
			  const int* string,
			  int length,
			  ByteCount* olen)
{
  static UniChar* iunicode = NULL;
  static char*    outbuf   = NULL;
  static int      warned   = 0;

  int  z;

  ByteCount inread;
  ByteCount outlen;

  OSStatus res;

  iunicode = realloc(iunicode, sizeof(UniChar)*length);
  for (z=0; z < length; z++)
    {
      iunicode[z] = string[z];
    }

  outbuf = realloc(outbuf, length*2);

  do
    {
      res = ConvertFromUnicodeToText(font->data.mac.convert, 
				     sizeof(UniChar)*length, iunicode,
				     kUnicodeLooseMappingsMask, 0,
				     NULL, NULL, NULL,
				     length*2, &inread, &outlen,
				     outbuf);

      if (res == kTECUnmappableElementErr)
	{
	  if (iunicode[inread>>1] == '?')
	    break;
	  iunicode[inread>>1] = '?';
	}
    }
  while (res == kTECUnmappableElementErr);

  if (res != noErr)
    {
      if (warned == 0)
	{
	  warned = 1;
	  zmachine_warning("Unable to convert game text to font text");
	}

      if (olen != NULL)
	(*olen) = 3;
      return "<?>";
    }

  if (olen != NULL)
    (*olen) = outlen;

  return outbuf;
}
#endif

#if 1
/*
 * This requires some explaination...
 *
 * CGContextSelectFont() is slow. So we want to use CGContextSetFont,
 * which is reasonably fast. However, that doesn't support *any* encoding
 * conversions, so we need to use ATSU to get the glyph details of the
 * text we're about to plot.
 */
static ATSUTextLayout make_atsu_layout(xfont* font,
					const int* string,
					int length)
{
  ATSUTextLayout lay;

  static UniChar* str = NULL;
  UniCharCount runlength[1];
  ATSUStyle    style[1];

  int x;

  str = realloc(str, sizeof(UniChar)*length);
  for (x=0; x<length; x++)
    {
      str[x] = string[x];
    }

  runlength[0] = length;
  style[0] = font->data.mac.style;
  ATSUCreateTextLayoutWithTextPtr(str, 0, length, length, 1, runlength, style,
				  &lay);

  return lay;
}

static CGGlyph* convert_glyphs(xfont* font,
			       const int* string,
			       int length,
			       SInt32* olen)
{
  static ATSUGlyphInfoArray* res = NULL;
  static CGGlyph* out = NULL;

  ATSUTextLayout lay;

  int x;

  ByteCount    bufsize;
  
  if (length <= 0)
    {
      *olen = 0;
      return NULL;
    }

  lay = make_atsu_layout(font, string, length);
  
  if (ATSUGetGlyphInfo(lay, 0, length, &bufsize, NULL) != noErr)
    {
      *olen = 0;
      return NULL;
    }
  res = realloc(res, bufsize);
  ATSUGetGlyphInfo(lay, 0, length, &bufsize, res);

  ATSUDisposeTextLayout(lay);
  
  *olen = 0;
  
  out = realloc(out, sizeof(CGGlyph)*res->numGlyphs);
  for (x=0; x<res->numGlyphs; x++)
    {
      if (res->glyphs[x].glyphID != 0xffff)
	out[(*olen)++] = res->glyphs[x].glyphID;
    }

  return out;
}
#endif

#ifdef USE_ATS
static void make_layout(xfont*         xf, 
			const int*     string, 
			int            len,
			ATSUTextLayout lo)
{
  static UniChar* ustr = NULL;
  int x;

  ustr = realloc(ustr, sizeof(UniChar)*len);
  for (x=0; x<len; x++)
    ustr[x] = string[x];

  ATSUSetTextPointerLocation(lo, ustr, 0, len, len);
  ATSUSetRunStyle(lo, xf->data.mac.style, 0, len);
}
#endif

XFONT_MEASURE xfont_get_text_width(xfont* xf,
				   const int* string,
				   int length)
{
#ifdef USE_ATS
  ATSUTextLayout lo;
  GrafPtr oldport;

  static UniChar* str = NULL;
  UniCharCount runlength[1];
  ATSUStyle    style[1];
  
  int x;

  if (length <= 0)
    return;

  ATSUTextMeasurement before, after, ascent, descent;

  if (xf->type == FONT_FONT3)
    return length*xfont_x;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  str = realloc(str, sizeof(UniChar)*length);
  for (x=0; x<length; x++)
    str[x] = string[x];

  runlength[0] = length;
  style[0] = xf->data.mac.style;
  ATSUCreateTextLayoutWithTextPtr(str, 0, length, length, 1, runlength, style,
				  &lo);
  
  ATSUMeasureText(lo, 0, length, &before, &after, &ascent, &descent);
  ATSUDisposeTextLayout(lo);

  SetPort(oldport);

  return (XFONT_MEASURE)(after+before)/65536.0;
#else
  GrafPtr oldport;

  char*     outbuf;
  ByteCount outlen;
  XFONT_MEASURE res;

  if (xf->type == FONT_FONT3)
    return length*xfont_x;

#ifdef USE_QUARTZ
  if (!enable_quartz)
    {
#endif
      GetPort(&oldport);
      SetPort(GetWindowPort(zoomWindow));

      select_font(xf);
      outbuf = convert_text(xf, string, length, &outlen);
      res = TextWidth(outbuf, 0, outlen);

      SetPort(oldport);
#ifdef USE_QUARTZ
    }
  else
    {
      CGPoint end;
      CGGlyph* glyph;

      if (winlastfont != xf)
	{
	  CGContextSetFont(carbon_quartz_context, xf->data.mac.cgfont);
	  CGContextSetFontSize(carbon_quartz_context, xf->data.mac.size);
	  winlastfont = xf;
	}
      glyph = convert_glyphs(xf, string, length, &outlen);
      CGContextSetTextPosition(carbon_quartz_context, 0, 0);
      CGContextSetTextDrawingMode(carbon_quartz_context, kCGTextInvisible);
      CGContextShowGlyphs(carbon_quartz_context, glyph, outlen);
      
      end = CGContextGetTextPosition(carbon_quartz_context);
      
      res = end.x;
    }
#endif

  return res;
#endif
}

static void plot_font_3(int chr, XFONT_MEASURE xpos, XFONT_MEASURE ypos)
{
  int x;
    
  if (chr > 127 || chr < 32)
    return;
  chr-=32;

  if (font_3.chr[chr].num_coords < 0)
    {
      zmachine_warning("Attempt to plot unspecified character %i",
		       chr+32);
      return;
    }

#ifdef USE_QUARTZ
  if (enable_quartz)
    {
      CGContextBeginPath(carbon_quartz_context);
      CGContextMoveToPoint(carbon_quartz_context,
			   (font_3.chr[chr].coords[0]*xfont_x) / 8.0 + xpos, 
			   ((8-font_3.chr[chr].coords[1])*xfont_y) / 8.0 + ypos);
      for (x=0; x<font_3.chr[chr].num_coords; x++)
	{
	  CGContextAddLineToPoint(carbon_quartz_context,
				  (font_3.chr[chr].coords[x<<1]*xfont_x) / 8.0 + xpos, 
				  ((8-font_3.chr[chr].coords[(x<<1)+1])*xfont_y) / 8.0 + ypos);
	}
      CGContextEOFillPath(carbon_quartz_context);
    }
  else
#endif
    {
      if (f3[chr] == nil)
	{
	  MoveTo((font_3.chr[chr].coords[0]*xfont_x) / 8.0 + 0.5, 
		 (font_3.chr[chr].coords[1]*xfont_y) / 8.0 + 0.5);
	  f3[chr] = OpenPoly();
	  for (x=0; x<font_3.chr[chr].num_coords; x++)
	    {
	      LineTo((font_3.chr[chr].coords[x<<1]*xfont_x) / 8.0 + 0.5, 
		     (font_3.chr[chr].coords[(x<<1)+1]*xfont_y) / 8.0 + 0.5);
	    }
	  ClosePoly();
	}
      OffsetPoly(f3[chr], xpos, ypos);
      PaintPoly(f3[chr]);
      OffsetPoly(f3[chr], -xpos, -ypos);
    }
}

void xfont_plot_string(xfont* font,
		       XFONT_MEASURE x, XFONT_MEASURE y,
		       const int* string,
		       int length)
{
  char*     outbuf;
  ByteCount outlen;

  Rect portRect;

  CGrafPtr thePort = GetQDGlobalsThePort();

  if (length <= 0)
    return;
  
  GetPortBounds(thePort, &portRect);

  if (font->type == FONT_FONT3)
    {
      int pos;
      
#ifdef USE_QUARTZ
      if (enable_quartz)
	{
	  CGContextSetRGBFillColor(carbon_quartz_context, 
				   (float)fg_col.red/65536.0,
				   (float)fg_col.green/65536.0,
				   (float)fg_col.blue/65536.0,
				   1.0);
	  
	  for (pos = 0; pos<length; pos++)
	    {
	      plot_font_3(string[pos], 
			  portRect.left + x + xfont_x*pos,
			  (portRect.bottom-portRect.top) + y);
	    }
	}
      else
#endif
	{
	  RGBForeColor(&fg_col);
	  
	  for (pos = 0; pos<length; pos++)
	    {
	      plot_font_3(string[pos], 
			  portRect.left+x + xfont_x*pos,
			  portRect.top-y - xfont_y);
	    }
	}

      return;
    }

#ifdef USE_ATS
 {
   ATSUTextLayout lo;
    ATSUTextMeasurement before, after, ascent, descent;
   
   ATSUCreateTextLayout(&lo);
   make_layout(font, string, length, lo);

   RGBForeColor(&fg_col);
   ATSUDrawText(lo, 0, length, (portRect.left + x)*65536.0, 
		(portRect.top - y)*65536.0);
   ATSUDisposeTextLayout(lo);
 }
#else
  outbuf = convert_text(font, string, length, &outlen);

# ifdef USE_QUARTZ
  if (!enable_quartz)
    {
# endif
      select_font(font);

      RGBBackColor(&bg_col);
      RGBForeColor(&fg_col);
      MoveTo(portRect.left+x, portRect.top - y);
      DrawText(outbuf, 0, outlen);
# ifdef USE_QUARTZ
    }
  else
    {
      CGGlyph* glyph;
      
      glyph = convert_glyphs(font, string, length, &outlen);

      if (outlen <= 0)
	return;
      
      /*
       * There is always CGContextSetFont, but while I'm able to create
       * the structure, I can't make CGContextShowText display *anything*...
       */
      if (winlastfont != font)
	{
	  CGContextSetFont(carbon_quartz_context, font->data.mac.cgfont);
	  CGContextSetFontSize(carbon_quartz_context, font->data.mac.size);
	  winlastfont = font;
	}
      
      CGContextSetRGBFillColor(carbon_quartz_context, 
			       (float)fg_col.red/65536.0,
			       (float)fg_col.green/65536.0,
			       (float)fg_col.blue/65536.0,
			       1.0);

      CGContextSetTextDrawingMode(carbon_quartz_context, kCGTextFill);
      CGContextSetTextPosition(carbon_quartz_context,
			       portRect.left + x, 
			       (portRect.bottom-portRect.top)+y);
      CGContextShowGlyphsAtPoint(carbon_quartz_context, 
				 portRect.left + x, 
				 (portRect.bottom-portRect.top)+y,
				 glyph, outlen);
    }
# endif
#endif
}

#endif
