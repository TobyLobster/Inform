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
 * Sound support
 */

#ifndef __SOUND_H
#define __SOUND_H

#include "file.h"

extern void sound_initialise  (void);
extern void sound_finalise    (void);
extern void sound_play_aiff   (int    channel,
			       ZFile* file,
			       int    offset,
			       int    len);
extern void sound_play_mod    (int    channel,
			       ZFile* file,
			       int offset,
			       int len);
extern void sound_stop_channel(int channel);

extern void sound_setup_channel(int channel,
				int volume,
				int repeat);

#endif
