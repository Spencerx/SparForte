------------------------------------------------------------------------------
-- BUSH OS.TTY- Terminal Emulation Information                              --
-- This version is for UNIX/Linux Commands                                  --
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
-- CVS: $Id: bush_os-tty.ads,v 1.2 2005/02/11 02:59:22 ken Exp $

with ada.strings.unbounded;
use  ada.strings.unbounded;

package bush_os.tty is


-- Terminal Attributes
--
-- Character sequences to change the print style, clear the
-- screen, move the cursor, etc.

type termAttributes is (normal, bold, inverse, cleop, cleol, up,
     right, bel, reset, clear, lines, cols);

type termAttributesArray is array (termAttributes) of unbounded_string;

term : termAttributesArray;
-- array containing the attribute strings

displayInfo : winsz_info;
-- dimensions of the terminal display


-- Attribute Procedures

procedure updateTtyAttributes( thisTerm : unbounded_string );
-- update the term array with the attributes for the display.
-- Run this procedure on BUSH startup or when the reset/clear
-- commands are used (in case the TERM variable has changed).

procedure updateDisplayInfo;
-- update the displayInfo record with the display dimensions.
-- Run this procedure at startup or when a SIGWINCH is
-- detected.


-- Basic TTY I/O

procedure simpleGetKey( ch : out character );
-- read a (raw) key from the keyboard without echoing to display

procedure simpleBeep;
-- ring the bell on the terminal (ie. send a control-G)

end bush_os.tty;
