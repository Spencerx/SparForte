------------------------------------------------------------------------------
-- Scanner Resources                                                        --
--                                                                          --
-- Part of SparForte                                                        --
------------------------------------------------------------------------------
--                                                                          --
--            Copyright (C) 2001-2011 Free Software Foundation              --
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

with gen_list,
     Ada.Numerics.Long_Complex_Types,
     Ada.Strings.Unbounded,
     Ada.Containers.Doubly_Linked_Lists,
     Unchecked_Deallocation,
     Gnat.Directory_Operations,
     Gnat.Dynamic_HTables,
     APQ.MySQL.Client,
     world;
use  world,
     Ada.Numerics.Long_Complex_Types,
     Ada.Strings.Unbounded,
     Gnat.Directory_Operations;

package scanner_res is

-- This packages is a temporary measure to handle data structures that are
-- cannot be converted to strings.  They are stored here in a linked list
-- of variant records.  When the memory is released, the cleanup functions
-- appropriate for that resource are called.
--
-- This package will be obsolete when the symbol table rewrite is finished.
------------------------------------------------------------------------------

-- Resources
------------------------------------------------------------------------------

-- Resource Types
--
-- An enumerated list of all the types of resources handled here.
-- These are defined even when support has been disabled.

type aResourceType is (
   none,
   mysql_connection,
   mysql_query,
   postgresql_connection,
   postgresql_query,
   complex_number,
   directory,
   memcache_connection,
   pen_canvas,
   doubly_linked_string_list,
   doubly_linked_string_list_cursor,
   string_hash_table
);

package doubly_linked_string_lists is new Ada.Containers.Doubly_Linked_Lists( unbounded_string );

type Hash_Position is new integer range 0..65535;

function String_Hash( key : unbounded_string ) return Hash_Position;

-- function Equal_Keys( key1, key2 : unbounded_string ) return boolean;

package string_hash_tables is new Gnat.Dynamic_HTables.Simple_HTable(
   Hash_Position,
   unbounded_string,
   null_unbounded_string,
   unbounded_string,
   String_Hash,
   "=" -- Equal_Keys
);

-- Resource Handle
--
-- A variant record for different types of resources.  This includes the
-- resource (typically a record of some kind), the block level in the
-- stack it was declared in.

type resHandle( rt : aResourceType ) is record
     --id         : natural; -- TBD
     blocklvl   : block;                      -- declaration block

     case rt is
     when mysql_connection =>
          c : APQ.MySQL.Client.Connection_Type;
     when mysql_query =>
          q : APQ.MySQL.Client.Query_Type;
     when postgresql_connection =>
          null; -- c : APQ.PostgreSQL.Client.Connection_Type;
     when postgresql_query =>
          null; -- q : APQ.PostgreSQL.Client.Query_Type;
     when complex_number =>
          cn : Complex;
     when directory =>
          dir : Dir_Type;
     when memcache_connection => null;
     when pen_canvas => null;
     when doubly_linked_string_list =>
          dlslList : doubly_linked_string_lists.List;
     when doubly_linked_string_list_cursor =>
          dlslCursor : doubly_linked_string_lists.Cursor;
     when string_hash_table =>
          sht : string_hash_tables.Instance;
     when none => null;
     end case;

end record;

-- A pointer to the variant record

type resPtr is access all resHandle;

procedure free is new Unchecked_Deallocation( resHandle, resPtr );

-- Resource Handle List
--
-- List is a linked list of resources
------------------------------------------------------------------------------

--function resSort( left, right : resPtr ) return boolean;
--package resHandleList is new gen_list( resPtr, resSort, "=" );
--
type resHandleID is private;

function to_unbounded_string( id : resHandleID ) return unbounded_string;
pragma inline( to_unbounded_string );

function to_resource_id( val : unbounded_string ) return resHandleID;
pragma inline( to_resource_id );

procedure declareResource( id : out resHandleID; rt : aResourceType; blocklvl : block );
-- create a resource

procedure findResource( id : resHandleID; rp : out resPtr );
-- retrieve a specific resource

--procedure saveResource( id : resHandleID; rp : in resPtr );
---- save a specific resource

procedure putResource( rp : resPtr );
-- display a resource for debugging.

procedure clearResource( id : resHandleID );
-- destroy a resource

procedure pullResourceBlock( blocklvl : block );
-- destroy all resources in a block when a block is exited

PRIVATE

function resSort( left, right : resPtr ) return boolean;
package resHandleList is new gen_list( resPtr, resSort, "=" );

type resHandleID is new resHandleList.AListIndex;

end scanner_res;

