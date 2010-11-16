------------------------------------------------------------------------------
-- BUSH AdaVox interface file                                               --
--                                                                          --
-- Part of BUSH                                                             --
------------------------------------------------------------------------------
--                                                                          --
--              Copyright (C) 2001-2005 Ken O. Burtch & FSF                 --
--                                                                          --
-- This is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  This is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with this;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- This is maintained at http://www.pegasoft.ca                             --
--                                                                          --
------------------------------------------------------------------------------
-- CVS: $Header: /home/cvsroot/bush/src/bush_os-sound.ads,v 1.2 2005/02/11 02:59:21 ken Exp $

with ada.strings.unbounded;
use  ada.strings.unbounded;

package bush_os.sound is

procedure Play( soundFile : unbounded_string; priority : integer := 0 );
-- Play a WAV or AU sound using AdaVox

procedure PlayCD( altCdPath : unbounded_string );
-- Play a music CD

procedure StopCD;
-- Stop music CD

procedure Mute;
-- mute music CD

procedure Unmute;
-- restore volume of music CD

end bush_os.sound;
