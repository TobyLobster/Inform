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
 * Deal with files
 */

#ifndef __FILE_H
#define __FILE_H

#include "ztypes.h"
#include <stdarg.h>

typedef enum {
    ZFile_save,
    ZFile_data,
    ZFile_transcript,
    ZFile_recording
} ZFile_type;

typedef struct ZFile ZFile;

extern ZFile* open_file      (const char* filename);
extern ZFile* open_file_write(const char* filename);
extern void   close_file     (ZFile* file);
extern ZByte  read_byte      (ZFile* file);
extern ZUWord read_word      (ZFile* file);
extern ZDWord read_dword     (ZFile* file);
extern ZUWord read_rword     (ZFile* file);
extern ZByte* read_page      (ZFile* file, int page_no);
extern ZByte* read_block     (ZFile* file, int start_pos, int end_pos);
extern void   read_block2    (ZByte*, ZFile*, int start_pos, int end_pos);
extern void   write_block    (ZFile* file, const ZByte* block, int length);
extern void   write_byte     (ZFile* file, ZByte byte);
extern void   write_word     (ZFile* file, ZWord word);
extern void   write_dword    (ZFile* file, ZDWord word);
extern void	  write_stringf  (ZFile* file, const char* format, ...) __printflike(2, 3);
extern void	  write_stringvf (ZFile* file, const char* format, va_list ap) __printflike(2, 0);
extern void	  write_stringu  (ZFile* file, const int* string);
extern void	  write_string   (ZFile* file, const char* string);
extern ZDWord get_file_size  (const char* filename);
extern int	  end_of_file	 (ZFile* file);

extern ZFile* get_file_write (int* size, const char* name, ZFile_type purpose);
extern ZFile* get_file_read  (int* size, const char* name, ZFile_type purpose);

#endif
