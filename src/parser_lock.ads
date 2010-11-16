------------------------------------------------------------------------------
-- BUSH Lock_File Package Parser                                            --
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
-- CVS: $Id: parser_lock.ads,v 1.2 2005/02/11 02:59:26 ken Exp $

with ada.strings.unbounded, world;
use  ada.strings.unbounded, world;

package parser_lock is


------------------------------------------------------------------------------
-- Lock_Files package identifiers
------------------------------------------------------------------------------

locks_lock_t      : identifier;
locks_unlock_t    : identifier;

------------------------------------------------------------------------------
-- HOUSEKEEPING
------------------------------------------------------------------------------

procedure StartupLockFiles;
procedure ShutdownLockFiles;

------------------------------------------------------------------------------
-- PARSE THE LOCK_FILES PACKAGE
------------------------------------------------------------------------------

procedure ParseLockLockFile;
procedure ParseLockUnlockFile;

end parser_lock;
