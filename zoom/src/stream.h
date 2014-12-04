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
 * Deal with input/output streams
 */

#ifndef __STREAM_H
#define __STREAM_H

extern void stream_prints              (const unsigned int* s);
extern void stream_printf              (const char* f, ...);
extern void stream_printc              (int c);
extern void stream_input               (const int* s);
extern int  stream_readline            (int* buf, int len, long int timeout);
extern void stream_buffering           (int buffer);
extern void stream_flush_buffer        (void);
extern void stream_remove_buffer       (const int* s);
extern void stream_update_unicode_table(void);

#endif
