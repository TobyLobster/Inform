/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

/*
 * Convert ZSCII strings to ASCII
 */

#ifndef __ZSCII_H
#define __ZSCII_H

#include <ctype.h>

#include "ztypes.h"

#ifdef DEBUG
extern char*		zscii_to_ascii        (ZByte* string, int* len);
#endif

extern unsigned int*	zscii_to_unicode      (ZByte* string, int* len);
extern int		zstrlen               (ZByte* string);
extern void		pack_zscii            (unsigned int* string,
					       int strlen,
					       ZByte* packed,
					       int packlen);
extern void		zscii_install_alphabet(void);

extern int* zscii_unicode;

static inline unsigned char zscii_get_char(unsigned int unichar) {
    /* Function that converts a unicode character to a ZSCII one */
    int ch;
    
    /* 32-127 are standard ASCII */
    if (unichar >= 32 && unichar < 127) return unichar;
    
    
    /* Possible input control characters */
    if (unichar == 13 || unichar == 10) return 13;
    if (unichar == 9 || unichar == 27) return unichar;
    
    /* 155-251 are 'extra' chracters */
    for (ch=155; ch<=251; ch++) {
	if (zscii_unicode[ch] == unichar) return ch;
    }
    
    /* 
     * The 1.1 spec provides for directly encoding unicode characters, but this is rarely sensible
     * in the context that a Z-Machine encodes characters (unless 2-character commands are ever
     * useful)
     *
     * Behaviour here seems to be undefined, however, frotz encodes unknown characters as '?', so
     * that's also what we do
     */
    return '?';
}

static inline int unicode_to_lower(int unichar) {
    /* Basic unicode character-to-lowercase routine */
    
    /* Use the ANSI stuff if the character is ASCII */
    if (unichar < 127) return tolower(unichar);
    
    /* Latin-1 lowercasing */
    /* (Fairly naive algorithm. SS won't lowercase right if we're dealing with German text, for example) */
    if (unichar >= 192 && unichar <= 222) return unichar + 32;
    
    /* Other character sets could go here if we ever cared. */
    
    /* Default is to do nothing */
    return unichar;
}

#endif
