------------------------------------------------------------------------------
-- Parser Aux (Parser Support)                                              --
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
-- OUT ANY WARRANTY;  without even the  iAsmplied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with this;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- This is maintained at http://www.pegasoft.ca                             --
--                                                                          --
------------------------------------------------------------------------------

with ada.text_io,
     Interfaces.C,
     string_util,
     script_io,
     user_io,
     parser;
use  ada.text_io,
     Interfaces.C,
     string_util,
     script_io,
     user_io,
     parser;


package body parser_aux is

use bush_os.HEptrs;

function isExecutingCommand return boolean is
  -- True if OK to execute a statement that does work.
  -- That is, the parser isn't skipping the line because of
  -- an error or exiting a block.
begin
  return not error_found and not exit_block and not syntax_check;
end isExecutingCommand;
--pragma inline( isExecutingCommand );

procedure discardUnusedIdentifier( id : identifier ) is
  -- if an identifier has been not been assigned a type,
  -- assume it's unused and discard it.
  b : boolean;
begin
  if id /= eof_t then
     if identifiers( id ).kind = new_t or identifiers( id ).kind = eof_t then
        b := deleteIdent( id );
     end if;
  end if;
end discardUnusedIdentifier;

procedure makeTempFile( s : out unbounded_string ) is
  -- create a unique temporary filename
  LinuxPath : string := "/tmp/sparXXXXXX" & ASCII.NUL;
  result : aFileDescriptor;
  closeResult : int;
begin
  s := null_unbounded_string;
  mkstemp( result, LinuxPath );
  if result < 0 then
     err( "makeTempFile: mkstemp failed" & OSError( C_errno ) );
     s := null_unbounded_string;
  else
<<retry1>> closeResult := close( result ); -- not the most secure
     if closeResult < 0 then
        if C_errno = EINTR then
           goto retry1;
        end if;
     end if;
     for i in aLinuxPath'range loop
         exit when LinuxPath( i ) = ASCII.NUL;
         s := s & LinuxPath( i );
     end loop;
  end if;
end makeTempFile;

--function isEOF( fd : aFileDescriptor ) return boolean is
-- true if the file descriptor is at the end of file
--  ch     : character;
--  result : long_integer;
--  seekResult : long_integer;
--begin
--  read( result, fd, ch, 1 );                 -- read a single character
--  if result > 0 then                         -- read something?
--     seekResult := lseek( fd, -1, WHENCE_SEEK_CUR); -- move back one character
--  end if;
--  return result < 1;                         -- return if read reported EOF
--end isEOF;

procedure AssignParameter( ref : in reference; value : unbounded_string ) is
  -- assign value to an out or in out parameter
begin
   if ref.index = 0 then
      identifiers( ref.id ).value := value;
   else
      assignElement( ref.a_id, ref.index, value );
   end if;
end AssignParameter;
pragma inline( AssignParameter );

procedure GetParameterValue( ref : in reference; value : out unbounded_string )
is
begin
   if ref.index = 0 then
      value := identifiers( ref.id ).value;
   else
      value := arrayElement( ref.a_id, ref.index );
   end if;
end GetParameterValue;
pragma inline( GetParameterValue );

function stringField( i : identifier; f : natural ) return unbounded_string is
-- same as string_util.stringField except uses an identifier's value
begin
  return stringField( identifiers( i ).value, recSep, f );
end stringField;

procedure replaceField( i : identifier; f : natural; field : string ) is
-- same as string_util.replaceField except users an identifier's value
begin
  replaceField( identifiers( i ).value, recSep, f, field );
end replaceField;

function stringField( r : reference; f : natural ) return unbounded_string is
-- same as string_util.stringField except uses a reference
   tempStr : unbounded_string;
begin
  getParameterValue( r, tempStr );
  return stringField( tempStr, recSep, f );
end stringField;

procedure replaceField( r : reference; f : natural; field : string ) is
-- same as string_util.replaceField except users an identifier's value
   tempStr : unbounded_string;
begin
  getParameterValue( r, tempStr );
  replaceField( tempStr, recSep, f, field );
  assignParameter( r, tempStr );
end replaceField;

function OSerror( e : integer ) return string is
-- return an OS error message for error number e
  lastchar : natural := 0;
  ep       : anErrorPtr;
begin
  ep := strerror( e );
  for i in ep.all'range loop
      if ep(i) = ASCII.NUL then
         lastchar := i-1;
         exit;
      end if;
  end loop;
  return string( ep( 1..lastchar ) );
end OSerror;

function openSocket( serverName : unbounded_string; port : integer ) return aSocketFD is


  mySocket    : aSocketFD;     -- the socket
  myAddress   : aSocketAddr;   -- where it goes
  myServer    : aHEptr;        -- IP number of server
  myServerPtr : HEptrs.Object_Pointer;
  addrList    : addrListPtrs.Object_Pointer;
  Result      : int;

begin

  -- initialize a new TCP/IP socket
  -- 0 for the third param lets the kernel decide

  --Put_Line( "Initializing a TCP/IP socket" );
  --Put_Line( "Socket( " & PF_INET'img & ',' & SOCK_STREAM'img & ", 0 );" );

  mySocket := Socket( PF_INET, SOCK_STREAM, 0 );
  if mySocket = -1 then
     err( "error making socket: " & OSError( C_errno ) );
     return -1;
  end if;
  --New_Line;

  -- Lookup the IP number for the server

  --Put_Line( "Looking for information on " & to_string( serverName ) );

  myServer := GetHostByName( to_string( serverName ) & ASCII.NUL );
  myServerPtr := HEptrs.To_Pointer( myServer );
  if myServerPtr = null then
     if C_errno = 0 then
        err( "there is no server by the name '" & to_string( serverName ) & "'" );
     else
        err( "error looking up host: " & OSError( C_errno ) );
     end if;
     return -1;
  end if;

  --Put_Line( "IP number is" & myServerPtr.h_length'img & " bytes long" );
  addrList := addrlistPtrs.To_Pointer( myServerPtr.h_addr_list );
  --New_Line;

  -- Create the IP, port and protocol information

  --Put_Line( "Preparing connection destination information" );
  myAddress.family := AF_INET;
  myAddress.port   := htons( Interfaces.C.Unsigned_Short( port ) );
  memcpy( myAddress.ip'address, addrlist.all, myServerPtr.h_length );
  --New_Line;

  -- Open a connection to the server

  --Put_Line( "Connect( Result, Socket, Family/Address rec, F/A rec size )" );

<<retry1>> Connect( Result, mySocket, myAddress, myAddress'size/8 );

  --Put( "Connect( " & Result'img & "," );
  --Put(  myAddress.family'img & "/" );
  --PutIPNum( myAddress.ip );
  --Put(  "," & integer'image( myAddress'size / 8 ) & ")" );
  if Result /= 0 then
     if C_errno = EINTR then
        goto retry1;
     end if;
     err( "error connecting to server: " & OSerror( C_errno ) );
<<retry2>> Result := close( aFileDescriptor( mySocket ) );
     if Result < 0 then
        if C_errno = EINTR then
           goto retry2;
        end if;
     end if;
     return -1;
  end if;
  --New_Line;

  return mySocket;

end openSocket;

-- Parsing short-cuts

--procedure ParseSingleUniStringExpression( expr_val : out unbounded_string;
  --expr_type : out identifier ) is
--begin
  --expect( symbol_t, "(" );
  --ParseExpression( expr_val, expr_type );
  --if uniTypesOk( expr_type, string_t ) then
     --expect( symbol_t, ")" );
  --end if;
--end ParseSingleUniStringExpression;
--
--procedure ParseSingleStringExpression( expr_val : out unbounded_string;
  --expr_type : out identifier ) is
--begin
  --expect( symbol_t, "(" );
  --ParseExpression( expr_val, expr_type );
  --if baseTypesOk( expr_type, string_t ) then
     --expect( symbol_t, ")" );
  --end if;
--end ParseSingleStringExpression;
--
--procedure ParseSingleNumericExpression( expr_val : out unbounded_string;
  --expr_type : out identifier ) is
--begin
  --expect( symbol_t, "(" );
  --ParseExpression( expr_val, expr_type );
  --if uniTypesOk( expr_type, uni_numeric_t ) then
     --expect( symbol_t, ")" );
  --end if;
--end ParseSingleNumericExpression;


------------------------------------------------------------------------------
-- PROCESS TEMPLATE
--
-- Read a template and process embedded scripts.  This procedure is expected
-- to be invoked after the main script has run.
-- Exceptions: Caller should handle STATUS_ERROR, NAME_ERROR, MODE_ERROR, etc.
------------------------------------------------------------------------------

procedure processTemplate is
   f : file_type;
   ch : character;
   type aMode is ( noMode,                          -- shouldn't be used
                   gatheringStartTag,               -- looking for a start tag
                   gatheringScript,                 -- gathering script
                   gatheringEndTag,                 -- looking for end tag
                   outputTemplate                   -- writing out template
                  );
   mode : aMode := outputTemplate;                  -- what are we doing now
   bushStartTag   : string := "<?spar";             -- the start tag
   bushEndTag     : string := "?>";                 -- the end tag
   tag            : unbounded_string;               -- possible tag text
   tagCount       : natural := 0;                   -- characters in p. tag
   uncompressedScript : unbounded_string;           -- script being gathered
   -- lineno         : natural := 1;
   startingLineNo : natural := 1;
   -- save_lineno    : aLineNumber;                    -- swap space for line no
   lastLine : Positive_Count := 1;
begin
   gccOpt := true; -- force gcc errors since these will go into
   -- web servers (text) log so hilighting will be annoying
   if not unrestrictedTemplate then
      rshOpt := true;
      restriction_no_external_commands := true;
   end if;
   scriptFilePath := templatePath;
   open( f, in_file, to_string( templatePath ) );   -- open the template
   while not end_of_file( f ) loop                  -- while text to do
      get( f, ch );                                 -- get next character

      ----------------------------------------------------------------------
      -- Text_IO Automatically skips lines.  This should be rewritten.
      ----------------------------------------------------------------------

      if line( f ) - lastLine > 1 then
         for i in 1..line( f ) - lastLine -1 loop
             uncompressedScript := uncompressedScript & ASCII.LF;
         end loop;
      end if;
      lastLine := line( f );

      ----------------------------------------------------------------------
      -- Depending on the mode, interpret the template character
      ----------------------------------------------------------------------

      case mode is                                  -- are we searching for

      ----------------------------------------------------------------------
      -- Examining a possible script start tag?
      ----------------------------------------------------------------------

      when gatheringStartTag =>                     -- possible <?spar ?
-- put_line( "gst: read '" & ch & " at" & lineno'img & "', tag = '" & to_string( tag ) & "', tagCount = " & tagCount'img );
         tag := tag & ch;                           -- record in case not
         tagCount := tagCount + 1;                  -- count characters
         if tagCount < bushStartTag'length then     -- subset of tag?
            if ch /= bushStartTag(tagCount) then    -- match failed?
               mode := outputTemplate;              -- not a tag
               tagCount := 0;                       -- forget it
               if last_status = 0 then              -- we are outputting?
                  put( to_string( tag ) );          -- output template text
               end if;
            end if;
         elsif ch = bushStartTag( tagCount ) then   -- but if last matches
            mode := gatheringScript;                -- look for a script
            tagCount := 0;                          -- forget tag
            startingLineNo := integer( line( f ) );
         else
            mode := outputTemplate;                 -- not a tag
            tagCount := 0;                          -- forget it
            if last_status = 0 then                 -- we are outputting?
               put( to_string( tag ) );             -- output template text
            end if;
         end if;
         if end_of_line( f ) then                   -- EOL?
              -- lineno := lineno + 1;                 -- template line
              if last_status = 0 then               -- we are outputting?
                 new_line;                          -- output a line feed
              end if;
         end if;

      ----------------------------------------------------------------------
      -- Gathering a script?
      ----------------------------------------------------------------------

      when gatheringScript =>                       -- collecting text
--put_line( "read '" & ch & "', tag = '" & to_string( tag ) & "', tagCount = " & tagCount'img );
         if ch = bushEndTag(1) then                 -- possible end tag?
            tag := null_unbounded_string & ch;      -- record char
            tagCount := 1;                          -- first in tag
            mode := gatheringEndTag;                -- looking for tag
         else
            uncompressedScript := uncompressedScript & ch; -- add character
            if end_of_line( f ) then                -- EOL?
               -- lineno := lineno + 1;                -- template line
               uncompressedScript := uncompressedScript & ASCII.LF;
            end if;
         end if;

      ----------------------------------------------------------------------
      -- Examining a possible end tag?
      ----------------------------------------------------------------------

      when gatheringEndTag =>                       -- possible ?> ?
--put_line( "get: read '" & ch & "', tag = '" & to_string( tag ) & "', tagCount = " & tagCount'img );
         tag := tag & ch;                           -- record in case not
         tagCount := tagCount + 1;                  -- count characters
         if tagCount < bushEndTag'length then       -- subset of tag?
            if ch /= bushEndTag(tagCount) then      -- match failed?
               mode := gatheringScript;             -- continue w/script
               tagCount := 0;                       -- forget it
               uncompressedScript := uncompressedScript & tag; -- text is script
            end if;
         elsif ch = bushEndTag( tagCount ) then     -- but if last matches
            mode := outputTemplate;                 -- done, run scripts
            tagCount := 0;                          -- forget tag
         else
            mode := gatheringScript;                -- continue w/script
            tagCount := 0;                          -- forget it
            uncompressedScript := uncompressedScript & tag; -- text is script
         end if;
         if end_of_line( f ) then                   -- EOL?
            -- lineno := lineno + 1;                   -- template line
            uncompressedScript := uncompressedScript & ASCII.LF;
         end if;

      ----------------------------------------------------------------------
      -- We have a script.  Run it.
      ----------------------------------------------------------------------

         if mode = outputTemplate then
            -- interpretCommand( uncompressedScript );
            -- there should be a proc for this
            compileTemplate( uncompressedScript, startingLineNo );
            inputMode := fromScriptFile;               -- running a script
            error_found := false;                      -- no error found
            exit_block := false;                       -- not exit-ing a block
            cmdpos := firstScriptCommandOffset;        -- start at first char
            token := identifiers'first;                -- dummy, replaced by g_n_t
            -- don't reset line number (for error msgs) lineno := 1;
            getNextToken;                              -- load first token
            -- save_lineno := lineno;                     -- save line
            loop                                       -- run commands
               ParseGeneralStatement;
            exit when done or token = eof_t;           -- continue until done
            end loop;                                  --  or eof hit
            if not done then                           -- not exiting?
               expect( eof_t );                        -- should be nothing else
            end if;
            -- lineno := save_lineno;                     -- restore template line
               --DoRunTimeStatements( identifiers( token ).value, );
            uncompressedScript := null_unbounded_string; -- clear script
         end if;

      ----------------------------------------------------------------------
      -- Examining a template.
      ----------------------------------------------------------------------

      when outputTemplate =>
         if ch = bushStartTag(1) then               -- possible start tag?
            tag := null_unbounded_string & ch;      -- record char
            tagCount := 1;                          -- first in tag
            mode := gatheringStartTag;              -- looking for tag
         elsif end_of_line( f ) then                -- otherwise EOL?
            if last_status = 0 then                 -- we are outputting?
               put( ch );                           -- write character
            end if;
            -- lineno := lineno + 1;                   -- count template line
            if last_status = 0 then                 -- we are outputting?
               new_line;                            -- output a line feed
            end if;
         else                                       -- not EOL?
            if last_status = 0 then                 -- we are outputting?
               put( ch );                           -- write character
            end if;
         end if;

      when others =>                             -- unexpected mode
        err( "internal error: unknown template mode" );
      end case;

   end loop;                                     -- continue while text
   close( f );                                   -- close template file
   exception when end_error =>
   -- kludge: if a blank line is at the end of template, an end_error
   -- exception will be thrown.  I should fix the EOL handling...
      close( f );
end processTemplate;

---------------------------------------------------------
-- PARSER UTILITIES
---------------------------------------------------------

procedure DoQuit is
  -- Quit a script
begin
  done := true;                             -- stop parsing
  exit_block := true;                       -- exit any block
  done_sub := false;                        -- only leaving subprogram
  if trace then                             -- tracing? explain
     put_trace( "Terminating" );
  end if;
end DoQuit;

procedure DoReturn is
  -- Quit a user-defined subprogram
begin
  done := true;                             -- stop parsing
  exit_block := true;                       -- exit any block
  done_sub := true;                         -- only leaving subprogram
  if trace then                             -- tracing? explain
     put_trace( "Returning" );
  end if;
end DoReturn;

procedure parseProcedureCallSemicolon is
begin
  if token = symbol_t then
     if identifiers( token ).value = ";" then
        getNextToken;
     elsif identifiers( token ).value = "|" then
        err( "procedures cannot be used in a pipeline like commands" );
     elsif identifiers( token ).value = ">" then
        err( "procedure output cannot be redirected like commands" );
     elsif identifiers( token ).value = ">>" then
        err( "procedure output cannot be redirected like commands" );
     elsif identifiers( token ).value = "<" then
        err( "procedure input cannot be redirected like commands" );
     elsif identifiers( token ).value = "2>" then
        err( "procedure error output cannot be redirected like commands" );
     elsif identifiers( token ).value = "2>>" then
        err( "procedure error output cannot be redirected like commands" );
     elsif identifiers( token ).value = "&" then
        err( "procedures cannot be run in the background like commands" );
     else
        expect( symbol_t, ";" );
     end if;
  else
     expect( symbol_t, ";" );
  end if;
end parseProcedureCallSemicolon;

procedure parseFunctionCallSemicolon is
begin
  if token = symbol_t then
     if identifiers( token ).value = ";" then
        getNextToken;
     elsif identifiers( token ).value = "|" then
        err( "functions cannot be used in a pipeline like commands" );
     elsif identifiers( token ).value = ">" then
        err( "function output cannot be redirected like commands" );
     elsif identifiers( token ).value = ">>" then
        err( "function output cannot be redirected like commands" );
     elsif identifiers( token ).value = "<" then
        err( "function input cannot be redirected like commands" );
     elsif identifiers( token ).value = "2>" then
        err( "function error output cannot be redirected like commands" );
     elsif identifiers( token ).value = "2>>" then
        err( "function error output cannot be redirected like commands" );
     elsif identifiers( token ).value = "&" then
        err( "functions cannot be run in the background like commands" );
     else
        expect( symbol_t, ";" );
     end if;
  else
     expect( symbol_t, ";" );
  end if;
end parseFunctionCallSemicolon;

end parser_aux;
