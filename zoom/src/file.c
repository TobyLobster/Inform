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

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/stat.h>

#include "file.h"
#include "zmachine.h"

#if WINDOW_SYSTEM != 2 && WINDOW_SYSTEM != 3 && WINDOW_SYSTEM != 4

struct ZFile
{
  FILE* handle;
};

ZFile* open_file(char* filename)
{
  ZFile* res;

  res = malloc(sizeof(ZFile));
  res->handle = fopen(filename, "r");

  if (res->handle == NULL)
    {
      free(res);
      return NULL;
    }

  return res;
}

ZFile* open_file_write(char* filename)
{
  ZFile* res;

  res = malloc(sizeof(ZFile));
  res->handle = fopen(filename, "w");

  if (res->handle == NULL)
    {
      free(res);
      return NULL;
    }

  return res;
}

void   close_file(ZFile* file)
{
  fclose(file->handle);
  free(file);
}

ZByte* read_page(ZFile* file, int page_no)
{
  ZByte* page;

  page = malloc(4096);
  if (page == NULL)
    return NULL;
  
  fseek(file->handle, 4096*page_no, SEEK_SET);
  fread(page, 4096, 1, file->handle);

  return page;
}

ZByte* read_block(ZFile* file, int start_pos, int end_pos)
{
  ZByte* block;
  size_t rd;
  
  block = malloc(end_pos-start_pos);
  if (block == NULL)
    return NULL;

  if (fseek(file->handle, start_pos, SEEK_SET))
    zmachine_fatal("Failed to seek to position %i", start_pos);
  rd = fread(block, 1, end_pos-start_pos, file->handle);
  if (rd != end_pos-start_pos)
    zmachine_fatal("Tried to read %i items of 1 byte, got %i items",
		   end_pos-start_pos, rd);

  return block;
}

ZByte inline read_byte(ZFile* file)
{
  return fgetc(file->handle);
}

ZUWord read_word(ZFile* file)
{
  return (read_byte(file)<<8)|read_byte(file);
}

ZUWord read_rword(ZFile* file)
{
  return read_byte(file)|(read_byte(file)<<8);
}

void read_block2(ZByte* block, ZFile* file, int start_pos, int end_pos)
{
  fseek(file->handle, start_pos, SEEK_SET);
  fread(block, end_pos-start_pos, 1, file->handle);
}

ZDWord get_file_size(char* filename)
{
  struct stat buf;
  
  if (stat(filename, &buf) != 0)
    {
      return -1;
    }

  return buf.st_size;
}

int end_of_file(ZFile* file)
{
  return feof(file->handle)!=0;
}

void write_block(ZFile* file, ZByte* block, int length)
{
  fwrite(block, 1, length, file->handle);
}

inline void write_byte(ZFile* file, ZByte byte)
{
  fputc(byte, file->handle);
}

void write_word(ZFile* file, ZWord word)
{
  write_byte(file, word>>8);
  write_byte(file, word);
}

void write_dword(ZFile* file, ZDWord word)
{
  write_byte(file, word>>24);
  write_byte(file, word>>16);
  write_byte(file, word>>8);
  write_byte(file, word);
}

#elif WINDOW_SYSTEM == 2

#include <windows.h>

struct ZFile
{
  HANDLE file;
};

ZFile* open_file(char* filename)
{
  ZFile* f;

  f = malloc(sizeof(ZFile));

  f->file = CreateFile(filename,
		       GENERIC_READ,
		       FILE_SHARE_READ,
		       NULL,
		       OPEN_EXISTING,
		       FILE_ATTRIBUTE_NORMAL,
		       NULL);

  if (f->file == INVALID_HANDLE_VALUE)
    {
      free(f);
      return NULL;
    }

  return f;
}

ZFile* open_file_write(char* filename)
{
  ZFile* f;

  f = malloc(sizeof(ZFile));

  f->file = CreateFile(filename,
		       GENERIC_READ|GENERIC_WRITE,
		       FILE_SHARE_READ|FILE_SHARE_WRITE,
		       NULL,
		       CREATE_ALWAYS,
		       FILE_ATTRIBUTE_NORMAL,
		       NULL);

  if (f->file == INVALID_HANDLE_VALUE)
    {
      free(f);
      return NULL;
    }

  return f;
}

void close_file(ZFile* file)
{
  CloseHandle(file->file);
  free(file);
}

ZByte read_byte(ZFile* file)
{
  ZByte block[1];
  DWORD nread;

  if (!ReadFile(file->file, block, 1, &nread, NULL))
    zmachine_fatal("Unable to read byte from file");
  return block[0];
}

ZUWord read_word(ZFile* file)
{
  return (read_byte(file)<<8)|read_byte(file);
}

ZUWord read_dword(ZFile* file)
{
  return (read_byte(file)<<24)|(read_byte(file)<<16)|(read_byte(file)<<8)|read_byte(file);
}

ZUWord read_rword(ZFile* file)
{
  return read_byte(file)|(read_byte(file)<<8);
}

ZByte* read_block(ZFile* file,
		  int start_pos,
		  int end_pos)
{
  ZByte* block;
  DWORD  nread;

  block = malloc(sizeof(ZByte)*(end_pos-start_pos));

  if (SetFilePointer(file->file, start_pos, NULL, FILE_BEGIN) == -1)
    {
      zmachine_fatal("Unable to seek to %i", start_pos);
      free(block);
      return NULL;
    }
  if (!ReadFile(file->file, block, end_pos-start_pos, &nread, NULL))
    {
      zmachine_fatal("Unable to read %i bytes", end_pos-start_pos);
      free(block);
      return NULL;
    }

  if (nread != end_pos-start_pos)
    {
      zmachine_fatal("Tried to read %i bytes, but only got %i",
		     end_pos-start_pos, nread);
      free(block);
      return NULL;
    }

  return block;
}

void read_block2(ZByte* block,
		 ZFile* file,
		 int start_pos,
		 int end_pos)
{
  DWORD  nread;

  if (SetFilePointer(file->file, start_pos, NULL, FILE_BEGIN) == -1)
    zmachine_fatal("Unable to seek");
  if (!ReadFile(file->file, block, end_pos-start_pos, &nread, NULL))
    zmachine_fatal("Unable to read file");

  if (nread != end_pos-start_pos)
    zmachine_fatal("Tried to read %i bytes, but only got %i",
		   end_pos-start_pos, nread);
}

void write_block(ZFile* file, ZByte* block, int length)
{
  DWORD nwrite;
  
  WriteFile(file->file, block, length, &nwrite, NULL);
}

void write_byte(ZFile* file, ZByte byte)
{
  write_block(file, &byte, 1);
}

void write_word(ZFile* file, ZWord word)
{
  write_byte(file, word>>8);
  write_byte(file, word);
}

void write_dword(ZFile* file, ZDWord word)
{
  write_byte(file, word>>24);
  write_byte(file, word>>16);
  write_byte(file, word>>8);
  write_byte(file, word);
}

ZDWord get_file_size(char* filename)
{
  HANDLE hnd;
  ZDWord sz;

  hnd = CreateFile(filename,
		   GENERIC_READ,
		   FILE_SHARE_READ,
		   NULL,
		   OPEN_EXISTING,
		   FILE_ATTRIBUTE_NORMAL,
		   NULL);

  if (hnd == INVALID_HANDLE_VALUE)
    return -1;

  sz = GetFileSize(hnd, NULL);
  
  CloseHandle(hnd);
  
  return sz;
}

/* end_of_file not implemented: implement to fix the Windows port */

#elif WINDOW_SYSTEM == 3

/* Mac OS file handling functions */

#include <Carbon/Carbon.h>
#include "carbondisplay.h"

/* 
 * We add a couple of functions to deal with opening files straight from
 * FSRefs
 */

struct ZFile
{
  FSRef  fileref;
  SInt16 forkref;
  int    endOfFile;
};

static char* file_error_text(OSStatus stat)
{
  switch (stat)
    {
    case notOpenErr:
      return "Volume not found";
    case dirFulErr:
      return "Directory full";
    case dskFulErr:
      return "Disk full";
    case nsvErr:
      return "Volume not found";
    case ioErr:
      return "I/O error";
    case bdNamErr:
      return "Bad filename";
    case fnOpnErr:
      return "File not open";
    case eofErr:
      return "End of file";
    case posErr:
      return "Bad file position";
    case tmfoErr:
      return "Too many files open";
    case fnfErr:
      return "File not found";
    case wPrErr:
    case vLckdErr:
      return "Volume locked";
    case fLckdErr:
      return "File locked";
    case fBsyErr:
      return "File busy";
    case rfNumErr:
      return "Invalid reference number";
    default:
      {
	static char str[255];

	sprintf(str, "Unknown reason code - %i", (int) stat);
	return str;
      }
    }
}

ZFile* open_file(char* filename)
{
  FSRef ref;

  FSPathMakeRef(filename, &ref, NULL);

  return open_file_fsref(&ref);
}

ZFile* open_file_write(char* filename)
{
  FSRef    ref;
  FSSpec   spec;
  OSStatus erm;
  FInfo    inf;
  int      x;

  char*    dirname;
  UniChar* uniname;
  int      lastslash = -1;
  FSRef    parent;
  
  erm = FSPathMakeRef(filename, &ref, NULL);

  if (erm != fnfErr)
    {
      erm = FSDeleteObject(&ref);
      if (erm != noErr)
	return NULL;
    }
  
  dirname = malloc(strlen(filename)+1);
  uniname = malloc((strlen(filename)+1)*sizeof(int));
  strcpy(dirname, filename);
  for (x=0; filename[x] != 0; x++)
    {
      uniname[x] = filename[x];
      if (filename[x] == '/')
	lastslash = x;
    }
  uniname[x] = 0;
  
  if (lastslash == -1)
    {
      free(dirname);
      free(uniname);
      return NULL;
    }
  dirname[lastslash] = 0;
  
  erm = FSPathMakeRef(dirname, &parent, NULL);
  if (erm != NULL)
    {
      free(dirname);
      free(uniname);
      return NULL;
    }
  
  erm = FSCreateFileUnicode(&parent, strlen(filename) - lastslash-1, 
			    uniname + lastslash + 1, 
			    kFSCatInfoNone, NULL, &ref, &spec);
  
  if (erm != noErr)
      {
	free(dirname);
	free(uniname);
	return NULL;
      }

  free(dirname);
  free(uniname);
  
  FSpGetFInfo(&spec, &inf);
  
  inf.fdType    = 'BINA';
  inf.fdCreator = SIGNATURE;
  
  FSpSetFInfo(&spec, &inf);
  
  return open_file_write_fsref(&ref);
}

ZFile* open_file_fsref(FSRef* ref)
{
  HFSUniStr255 dfork;
  ZFile *file;
  SInt16 refnum;
  OSErr erm;

  FSGetDataForkName(&dfork);

  erm = FSOpenFork(ref, dfork.length, dfork.unicode, fsRdPerm, &refnum);
  
  if (erm != noErr)
    return NULL;

  file = malloc(sizeof(ZFile));
  file->fileref = *ref;
  file->forkref = refnum;
  file->endOfFile = 0;

  return file;
}

ZFile* open_file_write_fsref(FSRef* ref)
{
  HFSUniStr255 dfork;
  ZFile *file;
  SInt16 refnum;
  OSErr erm;

  FSGetDataForkName(&dfork);

  erm = FSOpenFork(ref, dfork.length, dfork.unicode, fsWrPerm, &refnum);
  
  if (erm != noErr)
    return NULL;

  file = malloc(sizeof(ZFile));
  file->fileref = *ref;
  file->forkref = refnum;
  file->endOfFile = 0;

  return file;
}

FSRef get_file_fsref(ZFile* file)
{
  return file->fileref;
}

void   close_file(ZFile* file)
{
  FSCloseFork(file->forkref);
  free(file);
}

ZByte* read_page(ZFile* file, int page_no)
{
  return read_block(file, 4096*page_no, 4096*page_no+4096);
}

ZByte* read_block(ZFile* file, int start_pos, int end_pos)
{
  ZByte* block;
  OSStatus erm;
  ByteCount rd;
  
  block = malloc(end_pos-start_pos);
  if (block == NULL)
    return NULL;

  erm = FSReadFork(file->forkref, fsFromStart, start_pos,
		   end_pos-start_pos, block, &rd);
  if (erm != noErr)
    zmachine_fatal("Error while reading from file - %s", file_error_text(erm));
  if (erm == eofErr) endOfFile = 1;
  if (rd != end_pos-start_pos)
    zmachine_fatal("Tried to read %i items of 1 byte, got %i items",
		   end_pos-start_pos, rd);

  return block;
}

ZByte inline read_byte(ZFile* file)
{
  char byte;
  OSErr res;

  res = FSReadFork(file->forkref, fsAtMark, 0, 1, &byte, NULL);
  if (res == eofErr) file->endOfFile = 1;
  return byte;
}

ZUWord read_word(ZFile* file)
{
  return (read_byte(file)<<8)|read_byte(file);
}

ZUWord read_rword(ZFile* file)
{
  return read_byte(file)|(read_byte(file)<<8);
}

void read_block2(ZByte* block, ZFile* file, int start_pos, int end_pos)
{
  OSErr erm;
  
  erm = FSReadFork(file->forkref, fsFromStart, start_pos,
		  end_pos-start_pos, block, NULL);
  if (erm == eofErr) file->endOfFile = 1;
}

ZDWord get_file_size(char* filename)
{
  FSRef ref;
  OSStatus res;

  res = FSPathMakeRef(filename, &ref, NULL);
  
  if (res != noErr)
    return -1;

  return get_file_size_fsref(&ref);
}

int end_of_file(ZFile* file)
{
  return file->endOfFile;
}

ZDWord get_file_size_fsref(FSRef* file)
{
  FSCatalogInfo inf;

  FSGetCatalogInfo(file, kFSCatInfoDataSizes, &inf, NULL, NULL, NULL);

  return inf.dataLogicalSize;
}

void write_block(ZFile* file, ZByte* block, int length)
{
  FSWriteFork(file->forkref, fsAtMark, 0, length, block, NULL);
}

inline void write_byte(ZFile* file, ZByte byte)
{
   FSWriteFork(file->forkref, fsAtMark, 0, 1, &byte, NULL); 
}

void write_word(ZFile* file, ZWord word)
{
  write_byte(file, word>>8);
  write_byte(file, word);
}

void write_dword(ZFile* file, ZDWord word)
{
  write_byte(file, word>>24);
  write_byte(file, word>>16);
  write_byte(file, word>>8);
  write_byte(file, word);
}

#endif

void write_string(ZFile* file, const char* string) {
  write_block(file, (const unsigned char*)string, (int)strlen(string));
}

void write_stringf(ZFile* file, const char* format, ...) {
  va_list ap;
  
  va_start(ap, format);
  write_stringvf(file, format, ap);
  va_end(ap);
}

void write_stringvf(ZFile* file, const char* format, va_list ap) {
  char buffer[4096];
  
  vsnprintf(buffer, 4096, format, ap);
  buffer[4095] = 0;
  
  write_string(file, buffer);
}

void write_stringu(ZFile* file, const int* string) {
  /* Maybe FIXME: write in UTF-8 format? */
  int len, x;
  char* str;
  
  for (len=0; string[len] != 0; len++);
  
  str = malloc(len+1);
  
  for (x=0; x<len; x++) {
    str[x] = string[x]<128?string[x]:'?';
  }
  str[x] = 0;
  
  write_string(file, str);
  
  free(str);
}
