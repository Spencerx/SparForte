------------------------------------------------------------------------------
-- BUSH Built-in Shell Commands                                             --
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
-- CVS: $Id: builtins.adb,v 1.6 2005/08/31 15:10:44 ken Exp $

with ada.text_io,
     ada.strings.unbounded.text_io,
     ada.strings.fixed,
     ada.calendar,
     APQ,
     bush_os,
     string_util,
     world,
     user_io,
     script_io,
     jobs,
     scanner_arrays,
     parser_aux,
     parser_db,
     parser_mysql,
     parser;  -- for pragma annotate
use  ada.text_io,
     ada.strings.unbounded.text_io,
     ada.strings.fixed,
     ada.calendar,
     APQ,
     bush_os,
     string_util,
     world,
     jobs,
     user_io,
     script_io,
     scanner_arrays,
     parser_aux,
     parser_db,
     parser_mysql,
     parser;  -- for pragma annotate

package body builtins is


-----------------------------------------------------------------------------
--  FIND PWD
--
-- Assign the current working directory to the current_working_directory
-- variable.
-- Determine current working directory and assign it to the current_working_
-- directory variable, else assign it a null string.
-- loosely modelled on bash/builtins/cd.def
-----------------------------------------------------------------------------

buffer : string( 1..4096 );

procedure findPwd is
begin
  C_reset_errno;
  getcwd( buffer, buffer'length );
  if C_errno /= 0 then
     put_line( standard_error, "findPwd: error getting current working directory, errno "
	& C_errno'img );
     current_working_directory := null_unbounded_string;
  end if; 
  current_working_directory := to_unbounded_string(
     buffer( 1..index( buffer, ASCII.NUL & "" ) - 1 ) ) ;
end findPwd;


-----------------------------------------------------------------------------
--  BIND PWD
--
-- Assign the current working directory to the current_working_directory
-- variable.
-- loosely modelled on bash/builtins/cd.def
-----------------------------------------------------------------------------

procedure bindPwd( symlinks : boolean := false ) is
begin
  findPwd;
  if current_working_directory /= null_unbounded_string then
     -- SYMBOLIC LINKS TO BE HANDLED HERE LATER
     --findIdent( to_unbounded_string( "PWD" ), pwd );
     --findIdent( to_unbounded_string( "OLDPWD" ), oldpwd );
     --if identifiers( pwd ).kind = string_t then
     --   if identifiers( oldpwd ).kind = string_t then
     --      identifiers( oldpwd ).value := identifiers( pwd ).value;
     --   end if;
     --   identifiers( pwd ).value := current_working_directory;
     --end if;
     null;
  end if;
end bindPwd;


-----------------------------------------------------------------------------
--  OLD_PWD
--
-- Old version of the builtin pwd command used in previous versions of Bush.
-- Syntax: old_pwd
-- loosely modelled on bash/builtins/cd.def
-----------------------------------------------------------------------------

function old_pwd return unbounded_string is
-- pwd: present working directory
begin
   bindPwd;
   return current_working_directory;
end old_pwd;


-----------------------------------------------------------------------------
--  OLD_CD
--
-- Old version of the builtin cd command used in previous versions of Bush.
-- Syntax: old_cd s
-- loosely modelled on bash/builtins/cd.def
-----------------------------------------------------------------------------

procedure old_cd( s : unbounded_string ) is
  pwd, oldpwd : identifier;
  path : unbounded_string := s;
  showPath : boolean := false;
  temp_id : identifier;
begin
  if length( path ) = 0 then                 -- no path?
     path := to_unbounded_string( "$HOME" ); -- then go home
  elsif Element( path, 1 ) = '~' then        -- leading tilda?
     Delete( path, 1, 1 );                   -- shortform for
     Insert( path, 1, "$HOME" );             -- home
  elsif path = "-" then                      -- minus path?
     path := to_unbounded_string( "$OLDPWD" ); -- short for OLDPWD
     showPath := inputMode = interactive or inputMode = breakout;
  end if;

  if head( path, 5 ) = "$HOME" then
     findIdent( to_unbounded_string( "HOME" ), temp_id );
     Delete( path, 1, 5 );
     Insert( path, 1, to_string( identifiers( temp_id ).value ) );
  elsif head( path, 7 ) = "$OLDPWD" then
     findIdent( to_unbounded_string( "OLDPWD" ), temp_id );
     Delete( path, 1, 7 );
     Insert( path, 1, to_string( identifiers( temp_id ).value ) );
  end if;

  -- CDPATH support not yet implmeneted.  Should go HERE, but
  -- is CDPATH such a good idea anyway?  Not usually!

  if chdir( to_string( path ) & ASCII.NUL ) = 0 then
     bindPwd;
-- it should also not take into account the nesting (should be global)
     findIdent( to_unbounded_string( "PWD" ), pwd );
     findIdent( to_unbounded_string( "OLDPWD" ), oldpwd );
     if pwd /= eof_t then
        if oldpwd /= eof_t then
           identifiers( oldpwd ).value := identifiers( pwd ).value;
        end if;
        identifiers( pwd ).value := current_working_directory;
     end if;
  else
     err( "No such path '" & to_string( path ) & "'" );
  end if;
  if showPath then
     put_line( current_working_directory );
  end if;
end old_cd;


-----------------------------------------------------------------------------
--  ENV (POSIX SHELL COMMAND)
--
-- env : show the attributes of an identifier / all identifiers (if eof_t)
-- Syntax: env [id]
-----------------------------------------------------------------------------

procedure env( id : identifier := eof_t ) is
  perc : integer;
begin
  if identifiers( id ).kind = new_t then
     discardUnusedIdentifier( id );
     err( "identifier not declared" );
     return;
  end if;
  if id /= eof_t then
     Put_Identifier( id );
     return;
  end if;
  for i in 1..identifiers_top-1 loop
    if identifiers( i ).kind /= keyword_t then
       Put_Identifier( i );
    end if;
  end loop;
  perc := integer( ( ( identifiers_top - 1 ) * 100 ) / identifiers'last );
  Put( "The symbol table is" );
  Put( perc'img );
  Put( "% full with" );
  Put( identifier'image( identifiers_top-1 ) );
  Put_Line( " identifiers." );
end env;


-----------------------------------------------------------------------------
--  ALTER (SQL COMMAND)
--
-- alter : SQL alter - change database configuration
-- Syntax: alter shell_word
-----------------------------------------------------------------------------

procedure alter( ap : argumentListPtr ) is
-- alter : SQL alter
  tempStr : unbounded_string;
begin
  if ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if not engineOpen then
        err( "no database connection open" );
     elsif currentEngine = Engine_PostgreSQL then
        DoSQLStatement( "alter " & tempStr );
     elsif currentEngine = Engine_MySQL then
        DoMySQLSQLStatement( "alter " & tempStr );
     else
        err( "internal error: unrecognized database engine" );
     end if;
  end if;
end alter;


-----------------------------------------------------------------------------
--  CLEAR (POSIX SHELL COMMAND)
--
-- clear : clear the screen / reset the terminal screen
-- Syntax: clear
-----------------------------------------------------------------------------

procedure clear( ap : argumentListPtr ) is
  term_id : identifier;
begin
  if ap'length /= 0 then
     err( "zero argument expected" );
  elsif isExecutingCommand then
     findIdent( to_unbounded_string( "TERM" ), term_id );
     terminalClear( identifiers( term_id ).value );
  end if;
end clear;


-----------------------------------------------------------------------------
--  DELETE (SQL COMMAND)
--
-- delete : SQL delete
-- Syntax: delete shell_word
-----------------------------------------------------------------------------

procedure delete( ap : argumentListPtr ) is
  tempStr : unbounded_string;
begin
  if ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if not engineOpen then
        err( "no database connection open" );
     elsif currentEngine = Engine_PostgreSQL then
        DoSQLStatement( "delete " & tempStr );
     elsif currentEngine = Engine_MySQL then
        DoMySQLSQLStatement( "delete " & tempStr );
     else
        err( "internal error: unrecognized database engine" );
     end if;
  end if;
end delete;


-----------------------------------------------------------------------------
--  DO HISTORY (POSIX SHELL COMMAND)
--
-- history: shell history control
-- history [-c | n]
-----------------------------------------------------------------------------

procedure do_history( ap : argumentListPtr ) is
  i            : integer;
  historyMax   : natural := 0;
  historyFirst : natural := 0;
  word         : unbounded_string;
  pattern      : unbounded_string;
  mustClearHistory : boolean := false;
  showHistory  : boolean := false;
  tempStr      : unbounded_string;
begin
  if ap'length = 0 then
     null;
  elsif ap'length /= 1 then
     err( "zero or one argument expected" );
     return;
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if tempStr = "-c" then
        clearHistory;
        return;
     end if;
     historyMax := natural( to_numeric( tempStr ) );
     if historyMax > historyArray'last then
        historyMax := historyArray'last;
     end if;
  end if;

  -- If the user has requested a maximum number of lines (historyMax),
  -- then calculate the first line (historyFirst) to be shown.  If all
  -- should be shown, turn on showHistory flag immediately.
                                                                                
  if historyMax /= 0 then
     if historyNext - historyMax < 1 then
        historyFirst := historyArray'last - historyMax + historyNext;
     else
        historyFirst := historyNext- historyMax;
     end if;
  end if;
  showHistory := historyFirst = 0 or historyFirst = historyNext;
                                                                                
  -- Determine the starting point in the history array.  The history
  -- array wraps around to the first element when it has been filled.
                                                                                
  if historyNext = historyArray'last then
     i := 1;
  else
     i := historyNext + 1;
  end if;
                                                                                
  -- Walk the history array and show the contents.  Wrap around when the
  -- end of array is reached.
                                                                                
  loop
    if i = historyArray'last then
       i := 1;
    end if;
    exit when i = historyNext;
    if historyFirst = i then
       showHistory := true;
    end if;
    if length( history( i ).line ) > 0 then
       if showHistory then
          put( i'img );
          put( ": " );
          put( getDateString( history( i ).time ) );
          put( " | " );
          put( history( i ).pwd );
          put( " | " );
          put_line( history( i ).line );
       end if;
    end if;
    i := i + 1;
  end loop;
end do_history;


-----------------------------------------------------------------------------
--  INSERT (SQL COMMAND)
--
-- insert: SQL insert - add a row to a database table
-- Syntax: insert shell_word
-----------------------------------------------------------------------------

procedure insert( ap : argumentListPtr ) is
  tempStr : unbounded_string;
begin
  if ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if not engineOpen then
        err( "no database connection open" );
     elsif currentEngine = Engine_PostgreSQL then
        DoSQLStatement( "insert " & tempStr );
     elsif currentEngine = Engine_MySQL then
        DoMySQLSQLStatement( "insert " & tempStr );
     else
        err( "internal error: unrecognized database engine" );
     end if;
  end if;
end insert;


-----------------------------------------------------------------------------
--  CD (POSIX SHELL COMMAND)
--
-- cd: change current directory
-- Syntax: cd - | shell_word
-----------------------------------------------------------------------------

procedure cd( ap : argumentListPtr ) is
  tempStr : unbounded_string;
begin
  if rshOpt then
     err( "cd is not allowed in a " & optional_bold( "restricted shell" ) );
  elsif ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     old_cd( tempStr );
  end if;
end cd;


-----------------------------------------------------------------------------
--  JOBS (POSIX SHELL COMMAND)
--
-- jobs: show a list of running background jobs
-- Syntax: jobs
-----------------------------------------------------------------------------

procedure jobs( ap : argumentListPtr ) is
-- jobs: list running jobs
begin
  if ap'length /= 0 then
     err( "no arguments expected" );
  elsif isExecutingCommand then
     putJobList;
  end if;
end jobs;


-----------------------------------------------------------------------------
--  PWD (POSIX SHELL COMMAND)
--
-- pwd: show the present (current) working directory
-- Syntax: pwd
-----------------------------------------------------------------------------

procedure pwd( ap : argumentListPtr ) is
-- pwd: present working directory (also updated current_working_directory)
begin
  if ap'length /= 0 then
     err( "no arguments expected" );
  elsif isExecutingCommand then
     put_line( old_pwd );
  end if;
end pwd;                                                                                

-----------------------------------------------------------------------------
--  SELECT (SQL COMMAND)
--
-- select: SQL select - display rows from database tables
-- Syntax: select shell_word
-----------------------------------------------------------------------------

procedure SQLselect( ap : argumentListPtr ) is
-- SQL select: SQL select statement
  tempStr : unbounded_string;
begin
-- put_line( "length = " & ap'length'img ); -- DEBUG
-- if ap'length > 0 then
   -- put_line( "param = " & ap( 1 ).all );
-- end if;
  if ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if not engineOpen then
        err( "no database connection open" );
     elsif currentEngine = Engine_PostgreSQL then
        DoSQLSelect( "select " & tempStr );
     elsif currentEngine = Engine_MySQL then
        DoMySQLSQLSelect( "select " & tempStr );
     else
        err( "internal error: unrecognized database engine" );
     end if;
  end if;
end SQLselect;


-----------------------------------------------------------------------------
--  STEP (BUSH BUILTIN)
--
-- step: in breakout mode, run the next line and show a command prompt
-- Syntax: step
-----------------------------------------------------------------------------

procedure step( ap : argumentListPtr ) is
begin
  if ap'length /= 0 then
     err( "zero arguments expected" );
  elsif inputMode /= breakout then
     err( "step can only be used when you break out of a script" );
  elsif isExecutingCommand then
     done := true;
     breakoutContinue := true;
     stepFlag1 := true;
     put_trace( "stepping" );
  end if;
end step;


-----------------------------------------------------------------------------
--  DO TRACE (BUSH BUILTIN)
--
-- trace: turn source line tracing on or off, or show the current setting
-- Syntax: trace [true | false ]
-----------------------------------------------------------------------------

procedure do_trace( ap : argumentListPtr ) is
  tempStr : unbounded_string;
begin
  if ap'length = 0 then
     if isExecutingCommand then
        if trace then
           put_line( "Trace is currently on" );
        else
           put_line( "Trace is currently off" );
        end if;
     end if;
  elsif ap'length > 1 then
     err( "zero or one argument expected" );
  elsif isExecutingCommand then -- or syntax_check then -- when debugging
     -- true (boolean) will be a value of 1, but true (shell word) will be
     -- "true".  This is not ideal since it should really check types.
     tempStr := to_unbounded_string( ap( 1 ).all );
     if ( tempStr = "true" & ASCII.NUL ) or ( tempStr = "1" & ASCII.NUL ) then
        trace := true;
        put_line( "Trace is on" );
     elsif ( tempStr = "false" & ASCII.NUL ) or ( tempStr = "0" & ASCII.NUL ) then
        trace := false;
        put_line( "Trace is off" );
     else
        err( "expected true or false" );
     end if;
  end if;
end do_trace;


-----------------------------------------------------------------------------
--  UNSET (POSIX SHELL COMMAND)
--
-- unset: remove an identifier from the symbol table
-- Syntax: unset identifier
-- Note: this uses a word, not an identifier token as in older versions of
-- BUSH.  If BUSH becomes more complex, this may need to be redesigned.
-----------------------------------------------------------------------------

procedure unset( ap : argumentListPtr ) is
  tempStr : unbounded_string;
  identToUnset : identifier;
begin
  if rshOpt then
     err( "unset is not allowed in a " & optional_bold( "restricted shell" ) );
  elsif ap'length /= 1 then
     err( "one argument expected" );
  elsif inputMode /= interactive and inputMode /= breakout then
     err( "unset is only allowed in an interactive session" );
  elsif onlyAda95 then
     err( "unset is not allowed with " & optional_bold( "pragma ada_95" ) );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     findIdent( tempStr, identToUnset );
     if identToUnset = eof_t then
        err( "identifier not declared" );
     elsif boolean(rshOpt) and then identifiers( identToUnset ).name = "PATH" then
        err( "unsetting PATH is not allowed in a " &
          optional_bold( "restricted shell" ) );
     elsif boolean(rshOpt) and then identifiers( identToUnset ).name = "HOME" then
        err( "unsetting HOME is not allowed in a " &
          optional_bold( "restricted shell" ) );
     elsif boolean(rshOpt) and then identifiers( identToUnset ).name = "PWD" then
        err( "unsetting PWD is not allowed in a " &
          optional_bold( "restricted shell" ) );
     elsif boolean(rshOpt) and then identifiers( identToUnset ).name = "OLDPWD" then
        err( "unsetting OLDPWD is not allowed in a " &
          optional_bold( "restricted shell" ) );
     elsif isExecutingCommand then
        -- record? delete any fields first (notice not recursive)
        if identifiers( identToUnset ).kind = root_record_t then
           for i in keywords_top..identifiers_top - 1 loop
               if identifiers( i ).field_of = identToUnset and not identifiers( i ).deleted then
                  if not deleteIdent( i ) then
                     err( "unable to unset identifier field " & to_string( identifiers( i ).name ) );
                  end if;
               end if;
           end loop;
        -- single dimensional array.  Free dynamic memory. (notice not recursive)
        elsif identifiers( identToUnset ).list then
           clearArray( arrayID( to_numeric( identifiers( identToUnset ).value ) ) );
        end if;
        if not deleteIdent( identToUnset ) then
           err( "unable to unset identifier" );
        end if;
     end if;
  end if;
end unset;


-----------------------------------------------------------------------------
--  ENV (POSIX SHELL COMMAND)
--
-- env: show the attributes of one/all identifier(s) from the symbol table
-- Syntax: env [identifier]
-- Note: this uses a word, not an identifier token as in older versions of
-- BUSH.  If BUSH becomes more complex, this may need to be redesigned.
-----------------------------------------------------------------------------

procedure env( ap : argumentListPtr ) is
  tempStr : unbounded_string;
  identToShow : identifier;
begin
  if rshOpt then
     err( "env is not allowed in a " & optional_bold( "restricted shell" ) );
  elsif ap'length > 1 then
     err( "zero or one argument expected" );
  -- elsif inputMode /= interactive and inputMode /= breakout then
  --    err( "env is only allowed in an interactive session" );
  elsif isExecutingCommand then
     if ap'length = 0 then
        put_all_identifiers;
     else
        tempStr := to_unbounded_string( ap( 1 ).all );
        delete( tempStr, length( tempStr ), length( tempStr ) );
        findIdent( tempStr, identToShow );
        if identToShow = eof_t then
           err( "identifier not declared" );
        elsif boolean(rshOpt) and then identifiers( identToShow ).name =  "PATH" then
           err( "env PATH is not allowed in a " &
             optional_bold( "restricted shell" ) );
        elsif boolean(rshOpt) and then identifiers( identToShow ).name = "HOME" then
           err( "env HOME is not allowed in a " &
              optional_bold( "restricted shell" ) );
        elsif boolean(rshOpt) and then identifiers( identToShow ).name = "PWD" then
           err( "env PWD is not allowed in a " &
             optional_bold( "restricted shell" ) );
        elsif boolean(rshOpt) and then identifiers( identToShow ).name = "OLDPWD" then
           err( "env OLDPWD is not allowed in a " &
             optional_bold( "restricted shell" ) );
        elsif isExecutingCommand then
           Put_Identifier( identToShow );
        end if;
     end if;
  end if;
end env;


-----------------------------------------------------------------------------
--  UPDATE (SQL COMMAND)
--
-- update: SQL update - update rows in a database table
-- Syntax: update shell_word
-----------------------------------------------------------------------------

procedure update( ap : argumentListPtr ) is
  tempStr : unbounded_string;
begin
  if ap'length /= 1 then
     err( "one argument expected" );
  elsif isExecutingCommand then
     tempStr := to_unbounded_string( ap( 1 ).all );
     delete( tempStr, length( tempStr ), length( tempStr ) );
     if not engineOpen then
        err( "no database connection open" );
     elsif currentEngine = Engine_PostgreSQL then
        DoSQLStatement( "update " & tempStr );
     elsif currentEngine = Engine_MySQL then
        DoMySQLSQLStatement( "update " & tempStr );
     else
        err( "internal error: unrecognized database engine" );
     end if;
  end if;
end update;


-----------------------------------------------------------------------------
--  WAIT (POSIX SHELL COMMAND)
--
-- wait: wait for all background jobs to finish running
-- Syntax: wait
-----------------------------------------------------------------------------

procedure wait( ap : argumentListPtr ) is
begin
  if ap'length /= 0 then
     err( "zero arguments expected" );
  elsif isExecutingCommand then
     wait4children;
  end if;
end wait;


-----------------------------------------------------------------------------
--  VM (BUSH BUILTIN)
--
-- vm: show the interal state of the virtual machine
-- (Not yet implemented)
-- Syntax: vm nr n | sr n | ir n
-----------------------------------------------------------------------------

procedure vm( regtype, regnum : unbounded_string ) is
  r : aVMRegister;
begin
  if to_string( regtype ) = "nr" then
     r := aVMRegister'value( " " & to_string( regnum ) );
     put( "numeric register " & r'img & " = " );
     put_line( VMNR( aVMNRNumber( r ) ) );
  elsif to_string( regtype ) = "sr" then
     put( "string register " & r'img & " = " );
     r := aVMRegister'value( " " & to_string( regnum ) );
     put_line( VMSR( aVMSRNumber( r ) ) );
  elsif to_string( regtype ) = "ir" then
     put( "index register " & r'img & " = " );
     r := aVMRegister'value( " " & to_string( regnum ) );
     put_line( VMIR( aVMIRNumber( r ) )'img );
     Put_Identifier( VMIR( aVMIRNumber( r ) ) );
  else
     put_line( "usage: vm nr|sr|ir, n" );
  end if;
end vm;

-----------------------------------------------------------------------------
--   HELP (POSIX SHELL COMMAND)
-- Syntax: help = help [ ident ]
-- Source: BUSH built-in
-----------------------------------------------------------------------------

procedure help( ap : argumentListPtr ) is
  helpTopic : unbounded_string;
  HTMLOutput : boolean := false;
  MANOutput  : boolean := false;
begin
  if ap'length = 0 then
     helpTopic := null_unbounded_string;
  else
     helpTopic := to_unbounded_string( ap( 1 ).all );
     delete( helpTopic, length( helpTopic ), length( helpTopic ) );
     if helpTopic = "-h" then
        HTMLOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     elsif helpTopic = "-m" then
        MANOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     end if;
  end if;

  if length( helpTopic ) = 0 then
     Put_Line( "The following topics are available:" );
     New_Line;
     Put_Line( "  arrays            exit            mysql               stats            " );
     Put_Line( "  calendar          expressions     name                step             " );
     Put_Line( "  case              files           new_line            strings.match    " );
     Put_Line( "  cd                for             null                strings          " );
     Put_Line( "  cgi               get             numerics            subtype          " );
     Put_Line( "  clear             get_line        open                System           " );
     Put_Line( "  close             history         os                  trace            " );
     Put_Line( "  command_line      if              pen                 type             " );
     -- command not implemented
     Put_Line( "  create            inkey           pragma              typeset          " );
     Put_Line( "  db                is_open         put                 units            " );
     Put_Line( "  declare           jobs            put_line            unset            " );
     Put_Line( "  delay             keys            pwd                 variables        " );
     Put_Line( "  delete            line            reset               wait             " );
     Put_Line( "  directory_operations lock_files   return              while                " );
     Put_Line( "  end_of_file       logout          set_input           ""?""            " );
     Put_Line( "  end_of_line       loop            sound                                " );
     Put_Line( "  env               mode            source_info                          " );
     New_Line;
     Put_Line( "You can also type an O/S word or a Bush script name." );
     return;
  end if;
  if helpTopic = "arrays" then
     Put_Line( "arrays - arrays package functions" );
     New_Line;
     Put_Line( "  first( a )               last( a )                length( a )");
     Put_Line( "  bubble_sort( a )         bubble_sort_descending( a )" );
     Put_Line( "  heap_sort( a )           heap_sort_descending( a )" );
     Put_Line( "  shuffle( a )             flip( a )" );
     Put_Line( "  shift_left( a )          shift_right( a )" );
     Put_Line( "  rotate_left( a )         rotate_right( a )" );
  elsif helpTopic = "calendar" then
     Put_Line( "calendar (package) - time and date operations:" );
     New_Line;
     Put_Line( "  t := clock               y := year( t )           m := month( t )" );
     Put_Line( "  d := day( t )            s := seconds( t )        split( t, y, m, d, s )" );
     Put_Line( "  t := time_of( y,m,d,s )  i := day_of_week( t )    t := to_time( j )" );
     Put_Line( "  j := to_julian( t ) - not complete                                 " );
     discardUnusedIdentifier( token );
  elsif helpTopic = "case" then
     Put_Line( "case - test multiple cases" );
     Put_Line( "  " & bold( "case" ) & " var " & bold( "is" ) &
       " " & bold( "when" ) & " literal|const[|...] => ..." &
       bold( "when" ) & " " & bold( "others" ) & " => ..." &
       bold( "end" ) & " " & bold( "case" ) );
  elsif helpTopic = "cd" then
     Put_Line( "cd - change directory" );
     Put_Line( "  - - the previous directory" );
  elsif helpTopic = "cgi" then
     Put_Line( "cgi (package) - process CGI commands and cookies:" );
     New_Line;
     Put_Line( "  parsing_errors             input_received             is_index" );
     Put_Line( "  cgi_method                 value( k, i, b )           key_exists( k, i )" );
     Put_Line( "  key_count( k )             argument_count             key( p )" );
     Put_Line( "  key_value_exists( k, v )   put_cgi_header( s )        put_html_head( t, m )" );
     Put_Line( "  put_html_heading( s, p )   put_html_tail              put_error_message( s )" );
     Put_Line( "  my_url                     get_environment( v )       line_count" );
     Put_Line( "  line_count_of_value        line( v )                  value_of_line( k, p )" );
     Put_Line( "  url_decode                 url_encode( s )            html_encode( s )" );
     Put_Line( "  set_cookie( k,v,e,p,d,s )  cookie_value( p )          cookie_count" );
     Put_Line( "  put_variables" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "clear" then
     Put_Line( "clear - reset tty device and clear the screen" );
  elsif helpTopic = "close" then
     Put_Line( "close - close an open file" );
     Put_Line( "  close( file )" );
--  elsif helpTopic = "command" then
--     Put_Line( "command - run a Linux command (instead of a built-in command)" );
--     Put_Line( "  " & bold( "command" ) & " cmd" );
  elsif helpTopic = "command_line" then
     Put_Line( "command_line (package) - count and read script arguments" );
     New_Line;
     Put_Line( "  argument( i ) - return argument i" );
     Put_Line( "  argument_count - number of arguments" );
     Put_Line( "  command_name - name used to execute the script");
     Put_Line( "  environment.environment_count - number of variables in the O/S environment " );
     Put_Line( "  environment.environment_value - return environment value i" );
     Put_Line( "  set_exit_status( i ) - change script exit status code");
     New_Line;
     Put_Line( "Bourne Shell shortcuts:" );
     Put_Line( "  $# - number of arguments" );
     Put_Line( "  $1...$9 - first 9 arguments" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "create" then
     Put_Line( "create - create a new file or overwrite an existing file" );
     Put_Line( "  create( file [, out_file | append_file] [, path ] )" );
     Put_Line( "The default type is out_file" );
     Put_Line( "The default path a temporary file name" );
  elsif helpTopic = "db" then
     Put_Line( "db (package) - APQ PostgreSQL database package interface" );
     New_Line;
     Put_Line( "  connect( dbname [,user ,pswd [,host [,port] ] ] )");
     Put_Line( "  append( stmt [,after] )     prepare( stmt [,after] )" );
     Put_Line( "  append_line( stmt )         append_quoted( stmt )");
     Put_Line( "  execute                     execute_checked( msg )");
     Put_Line( "  disconnect                  is_connected" );
     Put_Line( "  reset                       s := error_message" );
     Put_Line( "  s := notice_message         b := in_abort_state" );
     Put_Line( "  s := options                set_rollback_on_finalize( b )" );
     Put_Line( "  open_db_trace( f [,m] )     b := will_rollback_on_finalize" );
     Put_Line( "  close_db_trace              set_trace( b )" );
     Put_Line( "  b := is_trace               clear" );
     Put_Line( "  raise_exceptions( [b] )     report_errors( [b] )" );
     Put_Line( "  begin_work                  rollback_work" );
     Put_Line( "  commit_work                 rewind" );
     Put_Line( "  fetch[(r)]                  b := end_of_query" );
     Put_Line( "  n := tuple( t )             n := tuples" );
     Put_Line( "  n := columns                s := column_name( c )" );
     Put_Line( "  i := column_index( s )      b := is_null( c )" );
     Put_Line( "  s := value( c )             d := engine_of " );
     Put_Line( "  show                        list" );
     Put_Line( "  schema( t )                 users" );
     Put_Line( "  databases                        " );
  elsif helpTopic = "declare" then
     Put_Line( "declare - begin a new block" );
     Put_Line( "  [" & bold( "declare") & " declarations] " &
       bold( "begin" ) & " ... " & bold( "end" ) );
  elsif helpTopic = "delay" then
     Put_Line( "delay - wait (sleep) for a specific time" );
     Put_Line( "  " & bold( "delay" ) & " secs" );
  elsif helpTopic = "delete" then
     Put_Line( "delete - close and delete a file" );
     Put_Line( "  delete( file )" );
  elsif helpTopic = "directory_operations" then
     Put_Line( "directory_operations - directory operations package functions" );
     New_Line;
     Put_Line( "  dir_separator             change_dir( p )          remove_dir( p [, r])");
     Put_Line( "  get_current_dir           dir_name( p )            base_name( p [, s])");
     Put_Line( "  file_extension( p )       file_name( p )           format_pathname(p [,s])");
     Put_Line( "  expand_path( p [,s] )                                                    ");
  elsif helpTopic = "end_of_file" then
     Put_Line( "end_of_file - true if an in_file file has no more data" );
     Put_Line( "  end_of_file( file )" );
  elsif helpTopic = "end_of_line" then
     Put_Line( "end_of_line - true if an in_file file has reached the end of a line with get" );
     Put_Line( "  end_of_line( file )" );
  elsif helpTopic = "env" then
     Put_Line( "env - show an identifier/all identifiers" );
     Put_Line( "  " & bold( "env" ) & " [identifier]" );
     Put_Line( "  " & bold( "env" ) & " identifier [identifier...]" );
     Put_Line( "  " & bold( "env" ) & " (identifier [, identifier...])" );
  elsif helpTopic = "exit" then
     Put_Line( "exit - break out of a loop" );
     Put_Line( "  " & bold( "exit" ) & " or " &
       bold( "exit" ) & " " & bold("when" ) & " condition" );
  elsif helpTopic = "files" then
     Put_Line( "files - files package functions" );
     New_Line;
     Put_Line( "  exists( p )               is_absolute_path( p )    is_regular_file( p )");
     Put_Line( "  is_directory( p )         is_writable_file( p )    is_executable_file( p )");
     Put_Line( "  is_readable_file( p )     is_waiting_file( p )     file_length( p )");
     Put_Line( "  basename( p )             dirname( p )             last_modified( p )");
     Put_Line( "  last_changed( p )         last_accessed( p )       is_writable( p )  ");
     Put_Line( "  is_readable( p )          is_executable( p )                         ");
  elsif helpTopic = "for" then
     Put_Line( "for - for loop" );
     Put_Line( "  " & bold( "for" ) & " var " &
      bold( "in" ) & " [" & bold( "reverse" ) & "]" &
      " first..last " & bold( "loop" ) & " ... " &
      bold( "end" ) & " " & bold( "loop" ) );
  elsif helpTopic = "function" then
     Put_Line( "functions - user defined functions" );
     New_Line;
     Put_Line( "  " & bold( "function" ) & " f " & bold ( "return" ) & " t " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " f;" );
     New_Line;
     Put_Line( "  " & bold( "function" ) & " f( f1 : type [; f2:type...]) " & bold( "return" ) & " t " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " f;" );
     New_Line;
     Put_Line( "  " & bold( "function" ) & " f " & bold( "return" ) & " t " & bold( "is separate" ) & ";" );
     Put_Line( "   --load function from include file ""f.bush""" );
     New_Line;
     Put_Line( "Only constant ('in') parameters supported" );
  elsif helpTopic = "get" then
     Put_Line( "get - read a character from a line of text" );
     Put_Line( "  get ([file,] ch)" );
  elsif helpTopic = "get_line" then
     Put_Line( "get_line - read a line of text" );
     Put_Line( "  var := get_line [ (file) ]" );
  elsif helpTopic = "help" then
     Put_Line( "help - show help or script annotations" );
     Put_Line( "  -h - HTML output" );
     Put_Line( "  -m - UNIX manual page output" );
  elsif helpTopic = "history" then
     Put_Line( "history - list or clear the command line history" );
     Put_Line( "  history -c" );
     Put_Line( "  history [n]" );
  elsif helpTopic = "keys" then
     Put_Line( "Keyboard Keys:" );
     New_Line;
     Put_Line( "Emacs Mode:                          vi Mode:" );
     Put_Line( "  control-b - move backwards           J - move backwards" );
     Put_Line( "  control-f - move forwards            K - move forwards" );
     Put_Line( "  control-p - move up                  I - move up" );
     Put_Line( "  control-n - move down                M - move down" );
     Put_Line( "  control-x - erase line" );
     Put_Line( "  control-a - move to start            ^ - move to start" );
     Put_Line( "  control-e - move to end              $ - move to end" );
     Put_Line( "  control-r - search history" );
     Put_Line( "  control-] - character search" );
     Put_Line( "  tab       - complete filename        ESC ESC - complete filename" );
     Put_Line( "                                       ESC - enter/exit vi mode" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "if" then
     Put_Line( "if - conditional execution" );
     Put_Line( "  " & bold( "if" ) & " expression " & bold("then" ) &
       " ... [" & bold( "elsif" ) & " expr " & bold( "then" ) &
       " ...] [" & bold( "else" ) & " ...] " &
       bold( "end" ) & " " & bold( "if" ) );
  elsif helpTopic = "inkey" then
     Put_Line( "inkey - read a character from standard input without echoing" );
     Put_Line( "  c := inkey" );
  elsif helpTopic = "is_open" then
     Put_Line( "is_open - true if file is open" );
     Put_Line( "  is_open( file )" );
  elsif helpTopic = "jobs" then
     Put_Line( "jobs - list current status of commands running in the background" );
  elsif helpTopic = "line" then
     Put_Line( "line - the number of read/written lines" );
     Put_Line( "  line( file )" );
  elsif helpTopic = "logout" then
     Put_Line( "logout - exit a interactive login session" );
  elsif helpTopic = "lock_files" then
     Put_Line( "lock_files (package) - creating and deleting lock files" );
     New_Line;
     Put_Line( "  lock_files.lock_file( dir, file [,wait [,retries] )" );
     Put_Line( "  lock_files.lock_file( file [,wait [,retries] )" );
     Put_Line( "  lock_files.unlock_file( dir, file )" );
     Put_Line( "  lock_files.unlock_file( file )" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "loop" then
     Put_Line( "loop - general loop" );
     Put_Line( "  " & bold( "loop" ) & " ... " &
       bold( "end" ) & " " & bold( "loop" ) );
  elsif helpTopic = "new_line" then
     Put_Line( "new_line - start a new line" );
     Put_Line( "  new_line [(file)]" );
  elsif helpTopic = "match" then
     Put_Line( "strings.match - pattern matching with UNIX V7 regular expressions and PERL extensions" );
     Put_Line( "  bool := match( expression, string )" );
     New_Line;
     Put_Line( "^    - at beginning            .   - any character" );
     Put_Line( "$    - at end                  ?   - zero or one character" );
     Put_Line( "[s]  - any in set s            +   - one or more characters" );
     Put_Line( "[^s] - any not in set s        *   - zero or more characters" );
     Put_Line( "\    - escape character        (e) - nested expression" );
     Put_Line( "|    - alternative                                    " );
     New_Line;
     Put_Line( "Regular expressions are described in ""man 5 regexp""" );
  elsif helpTopic = "mysql" then
     Put_Line( "mysql (package) - APQ MySQL database package interface" );
     New_Line;
     Put_Line( "  connect( dbname [,user ,pswd [,host [,port] ] ] )");
     Put_Line( "  append( stmt [,after] )     prepare( stmt [,after] )" );
     Put_Line( "  append_line( stmt )         append_quoted( stmt )");
     Put_Line( "  execute                     execute_checked( msg )");
     Put_Line( "  disconnect                  is_connected" );
     Put_Line( "  reset                       s := error_message" );
     Put_Line( "                              b := in_abort_state" );
     Put_Line( "  s := options                set_rollback_on_finalize( b )" );
     Put_Line( "  open_db_trace( f [,m] )     b := will_rollback_on_finalize" );
     Put_Line( "  close_db_trace              set_trace( b )" );
     Put_Line( "  b := is_trace               clear" );
     Put_Line( "  raise_exceptions( [b] )     report_errors( [b] )" );
     Put_Line( "  begin_work                  rollback_work" );
     Put_Line( "  commit_work                 rewind" );
     Put_Line( "  fetch[(r)]                  b := end_of_query" );
     Put_Line( "  n := tuple( t )             n := tuples" );
     Put_Line( "  n := columns                s := column_name( c )" );
     Put_Line( "  i := column_index( s )      b := is_null( c )" );
     Put_Line( "  s := value( c )             d := engine_of " );
     Put_Line( "  show                        list" );
     Put_Line( "  schema( t )                 users" );
     Put_Line( "  databases                        " );
  elsif helpTopic = "declare" then
     Put_Line( "declare - begin a new block" );
     Put_Line( "  [" & bold( "declare") & " declarations] " &
       bold( "begin" ) & " ... " & bold( "end" ) );
  elsif helpTopic = "delay" then
     Put_Line( "delay - wait (sleep) for a specific time" );
     Put_Line( "  " & bold( "delay" ) & " secs" );
  elsif helpTopic = "mode" then
     Put_Line( "mode - the file mode (in_file, out_file, append_file)" );
     Put_Line( "  mode( file )" );
  elsif helpTopic = "name" then
     Put_Line( "name - name of an open file" );
     Put_Line( "  name( file )" );
  elsif helpTopic = "null" then
     Put_Line( "null - do nothing" );
  elsif helpTopic = "os" then
     Put_Line( "os - BUSH operating system binding" );
     Put_Line( "  system( string ) -- run shell command with C system()" );
     Put_Line( "  i := status;     -- status of last command" );
     New_Line;
     Put_Line( "Bourne Shell shortcuts:" );
     Put_Line( "  $? - status of last command" );
  elsif helpTopic = "open" then
     Put_Line( "open - open an existing file or open a socket" );
     Put_Line( "  open( file, in_file | out_file | append_file, path )" );
  elsif helpTopic = "procedure" then
     Put_Line( "procedure - user defined procedures" );
     New_Line;
     Put_Line( "  " & bold( "procedure" ) & " p " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " p;" );
     New_Line;
     Put_Line( "  " & bold( "procedure" ) & " p( f1 : type [; f2:type...]) " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " p;" );
     New_Line;
     Put_Line( "Only constant ('in') parameters supported" );
  elsif helpTopic = "pragma" then
     Put_Line( "pragma - interpreter directive" );
     New_Line;
     Put_Line( "  " & bold( "pragma" ) & " " &
       "ada_95 - enforce Ada 95 restrictions" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "annotate( [type,]""text"" ) - embed a comment for help command" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "assert( condition ) - with --debug, terminate program on condition" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "debug( `commands` ) - with --debug, execute debug commands" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "depreciated/deprecated( ""newscript"" ) - report script as obsolete by newscript" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "export( shell, var ) - export an environment variable" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "gcc_errors - same as --gcc-errors" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "import( shell, var ) - import an environment variable" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspect( var ) - perform 'env var' on --break breakout" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspection_peek - like a inspection_point but no breakout" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspection_point - break to command prompt if --break is used" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "no_command_hash - do not store command pathnames in the hash table" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "prompt_script( `commands` ) - commands to draw command prompt" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "template( html [, path] ) - script is acting as an HTML template processor" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "unchecked_import( shell, var ) - import without checking for existence" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "uninspect( var ) - undo pragma inspect" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "unrestricted_template( html [, path] ) - don't run template in restricted shell" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "volatile( var ) - load value from environment on every access" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_auto_declarations ) - " &
         "no auto command line declarations" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_external_commands ) - " &
         "disable operating system commands" );
  elsif helpTopic = "put" then
     Put_Line( "put - write to output, no new line" );
     Put_Line( "  put ( [file], expression [,picture] )" );
  elsif helpTopic = "put_line" then
     Put_Line( "put_line - write to output and start new line" );
     Put_Line( "  put_line ( [file], expression )" );
  elsif helpTopic = "pwd" then
     Put_Line( "pwd - present working directory" );
  elsif helpTopic = "reset" then
     Put_Line( "reset - reopen a file" );
     Put_Line( "  reset( file [,mode])" );
  elsif helpTopic = "return" then
     Put_Line( "return - exit script and return status code" );
     Put_Line( "  " & bold( "return") );
  elsif helpTopic = "typeset" then
     Put_Line( "typeset - change the type of a variable, declaring it if necessary" );
     Put_Line( "  " & bold( "typeset" ) & " var " &
       "[" & bold( "is" ) & " type]" );
     Put_Line( "The default type is universal_typeless" );
  elsif helpTopic = "set_input" or helpTopic = "set_output" or helpTopic = "set_error" then
     Put_Line( "set_input/output/error - input/output redirection" );
     New_Line;
     Put_Line( "  set_input( file )" );
     Put_Line( "  set_output( file )" );
     Put_Line( "  set_error( file )" );
     Put_Line( "The default files are standard_input, standard_output and standard_error" );
  elsif helpTopic = "skip_line" then
     Put_Line( "skip_line - discard the next line of input" );
     Put_Line( "  skip_line [(file)]" );
  elsif helpTopic = "sound" then
     Put_Line( "sound (package) - play music and sound" );
     New_Line;
     Put_Line( "  play( ""path"" [,pri] ) - play a sound at an optional priority" );
     Put_Line( "  playcd [( ""path"" )]   - play an audio cd in optional cd device path" );
     Put_Line( "  stopcd                - stop an audio cd" );
     New_Line;
  elsif helpTopic = "source_info" then
     Put_Line( "source_info (package) - information on the current script" );
     New_Line;
     Put_Line( "  enclosing_entity - name of script (if a procedure block)" );
     Put_Line( "  file - file name without a path" );
     Put_Line( "  line - current line number" );
     Put_Line( "  script_size - size of compiled script (bytes)" );
     Put_Line( "  source_location - file and line number" );
     Put_Line( "  symbol_table_size - number of variables" );
     New_Line;
     discardUnusedIdentifier( token );
  elsif helpTopic = "stats" then
     Put_Line( "stats - stats package functions" );
     New_Line;
     Put_Line( "  average( a )             max( a )                 min( a )");
     Put_Line( "  standard_deviation( a )  sum( a )                 variance( a )" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "subtype" then
     Put_Line( "subtype - create an alias for a type" );
     Put_Line( "  " & bold( "subtype" ) & " newtype " &
       bold( "is" ) & " oldtype" );
  elsif helpTopic = "System" then
     Put_Line( "System (package) - System package constants" );
     New_Line;
     Put_Line( "  System.System_Name            System.Fine_Delta" );
     Put_Line( "  System.Max_Int                System.Tick" );
     Put_Line( "  System.Min_Int                System.Storage_Unit" );
     Put_Line( "  System.Max_Binary_Modulus     System.Word_Size" );
     Put_Line( "  System.Max_Nonbinary_Modulus  System.Memory_Size" );
     Put_Line( "  System.Max_Base_Digits        System.Default_Bit_Order" );
     Put_Line( "  System.Max_Mantissa           System.Login_Shell" );
     Put_Line( "  System.Restricted_Shell" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "trace" then
     Put_Line( "trace - show verbose debugging information" );
     Put_Line( "  " & bold( "trace" ) & " " &
       bold( "true" ) & " or " & bold( "false" ) );
     Put_Line( "  trace - show current trace setting" );
  elsif helpTopic = "type" then
     Put_Line( "type - declare a new type or enumerated type" );
     Put_Line( "  " & bold( "type" ) & " newtype " &
       bold( "is" ) & " " & bold( "new" ) & " oldtype" );
     Put_Line( "  " & bold( "type" ) & " newenum " & bold( "is" ) &
       " ( enum1 [,enum2...])" );
     Put_Line( "  " & bold( "type" ) & " newarray " & bold( "is" ) &
       " array( low..high ) of item-type [:= array|( item, ...)]" );
     New_Line;
     Put_Line( "Standard types:" );
     Put_Line( " boolean     integer            natural            short_short_integer     " );
     Put_Line( " character   long_float         positive           socket_type" );
     Put_Line( " duration    long_integer       short_float        string" );
     Put_Line( " file_type   long_long_float    short_integer      universal_numeric" );
     Put_Line( " file_mode   long_long_integer  short_short_float  universal_string" );
     Put_Line( " float       unbounded_string                      universal_typeless" );
     Put_Line( " complex                                                             " );
  elsif helpTopic = "units" then
     Put_Line( "units (package) - measurement conversions:" );
     New_Line;
     Put_Line( "  inches2mm(e) - inches to millimeters   mm2inches(e) - millimeters to inches " );
     Put_Line( "  feet2cm(e)   - feet to centimeters     cm2inches(e) - centimeters to inches " );
     Put_Line( "  yards2m(e)   - yards to meters         m2yards(e)   - meters to yards       " );
     Put_Line( "  miles2km(e)  - miles to kilometers     km2miles(e)  - kilometers to miles   " );
     Put_Line( "  ly2pc(e)     - lightyears to parsecs   pc2ly(e)     - parsecs to lightyears " );
     Put_Line( "  sqin2sqcm(e) - sq. inches to sq. cm    sqcm2sqin(e) - sq. cm to sq. inches " );
     Put_Line( "  sqft2sqm(e)  - sq. feet to sq. meters  sqm2sqft(e)  - sq. m to sq. feet    " );
     Put_Line( "  sqyd2sqm(e)  - sq. yards to sq. meters sqm2sqyd(e)  - sq. m to sq. yards   " );
     Put_Line( "  acres2hectares( e ) - acres to h.      hectares2acres(e) - h. to acres     " );
     Put_Line( "                                         sqkm2sqmiles(e)  - sq. km to sq. miles  " );
     Put_Line( "  oz2grams(e)  - ounces to grams         grams2oz(e)  - grams to ounces      " );
     Put_Line( "  usdryoz2l(e) - US dry oz to liters     l2usdryoz(e) - liters to US dry oz  " );
     Put_Line( "  usliqoz2l(e) - US liquid oz to liters  l2usliqoz(e) - liters to US liq oz  " );
     Put_Line( "  troz2g(e)    - Troy ounces to grams    g2troz(e)    - grams to Troy ounces " );
     Put_Line( "  lb2kg(e)     - pounds to kilograms     kg2lb(e)     - kilograms to pounds  " );
     Put_Line( "  tons2tonnes(e) - tons to tonnes        tonnes2tons(e) - tons to tonnes     " );
     Put_Line( "  floz2ml(e)   - fl. oz. to millilitres  ml2floz(e)   - millilitres to fl oz " );
     Put_Line( "  usfloz2ml(e) - US fl. oz. to ml        ml2usfloz(e) - ml to US fl oz " );
     Put_Line( "  usfloz2floz(e) - US to imperial fl oz  flozususfloz(e) - imp to US fl oz " );
     Put_Line( "  pints2l(e)   - pints to litres         l2quarts(e)  - litres to quarts     " );
     Put_Line( "  gal2l(e)     - gallons to litres       l2gal(e)     - litres to gallons    " );
     Put_Line( "  cucm2floz(e) - cubic cm to imp fl oz   floz2cucm(e) - imp fl oz to cubic cm" );
     Put_Line( "  cucm2usfloz(e) - cubic cm to US fl oz  usfloz2cucm(e) - US fl oz to cubic cm" );
     Put_Line( "  f2c(e)       - Fahrenheit to Celsius   c2f(e)       - Celsius to Fahrenheit" );
     Put_Line( "  k2c(e)       - Kelvin to Celsius       c2k(e)       - Celsius to Kelvin    " );
     Put_Line( "  bytes2mb(e)  - bytes to megabytes      mb2bytes(e)  - megabytes to bytes   " );
  elsif helpTopic = "unset" then
     Put_Line( "unset - delete an identifier" );
     New_Line;
     Put_Line( "  " & bold( "unset" ) & " ident" );
     Put_Line( "  " & bold( "unset" ) & " (ident)" );
  elsif helpTopic = "wait" then
     Put_Line( "wait - wait for all background commands to finish" );
     New_Line;
     Put_Line( "  " & bold( "wait" ) );
  elsif helpTopic = "while" then
     Put_Line( "while - while loop" );
     New_Line;
     Put_Line( "  " & bold( "while" ) &
       " expression " & bold( "loop" ) & " ... " &
       bold( "end" ) & " " & bold( "loop" ) );
  elsif helpTopic = "expressions" then
     Put_Line( "expressions" );
     New_Line;
     Put_Line( "+ - not - uniary operations" );
     New_Line;
     Put_Line( "** - exponentiation" );
     New_Line;
     Put_Line( "* - multiplication             and - bitwise and" );
     Put_Line( "/ - division                   or  - bitwise or" );
     Put_line( "& - string concatenation       xor - bitwise xor" );
     New_Line;
     Put_Line( "+ - addition                   - - subtraction" );
     New_Line;
     Put_Line( "= /= > >= < <= in not in- relational operators" );
     New_Line;
     Put_Line( "and or xor - boolean operators" );
     New_Line;
     Put_Line( "@ - itself                    % - last put" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "numerics" then
     Put_Line( "numerics - numerics package constants/functions" );
     New_Line;
     Put_Line( "  e                    log2_e                  log10_e             ln10" );
     Put_Line( "  ln2                  pi                      pi_by_2             pi_by_4" );
     Put_Line( "  pi_under_1                                   pi_under_2" );
     Put_Line( "  sqrt_pi_under_2                              sqrt_2" );
     Put_Line( "  sqrt_2_under_1" );
     New_Line;
     Put_Line( "  sqrt( x )            log( x [,base] )         exp( x )           random" );
     Put_Line( "  shift_left( x, b )   rotate_left( x, b )      shift_right_arithmeric( x, b )" );
     Put_Line( "  shift_right( x, b )  rotate_right( x, b )     floor( x )         ceiling( x )" );
     Put_Line( "  rounding( x )        truncation( x )          unbiased_rounding( x )         " );
     Put_Line( "  remainder( x, y )    copy_sign( x, y )        leading_part( x, y )           " );
     Put_Line( "  exponent( x )        fraction( x )            max( m, n )         min( m, n )" );
     Put_Line( "  machine( x )         scaling( x, y )          value( s )          pos( c )   " );
     Put_Line( "  sturges( l, h, t )   md5( s )                 rnd( n )            serial     " );
     Put_Line( "  odd( i )             even( i )                                               " );
     New_Line;
     Put_Line( "  sin( x [,cycle] )    arcsin( x [,cycle] )     sinh( x )          arcsinh( x )" );
     Put_Line( "  cos( x [,cycle] )    arccos( x [,cycle] )     cosh( x )          arccosh( x )" );
     Put_Line( "  tan( x [,cycle] )    arctan( x, y [,cycle] )  tanh( x )          arctanh( x )" );
     Put_Line( "  cot( x [,cycle] )    arccot( x, y [,cycle] )  coth( x )          arccoth( x )" );
     New_Line;
     Put_Line( "  re( complex )        im( complex )            modulus( complex )            " );
     Put_Line( "  set_re( complex, r ) set_im( complex, i )     argument( complex )           " );
     New_Line;
     Put_Line( "  abs( x ) is not ""numerics.abs( x )"" because it's not in the numerics package" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "pen" then
     Put_Line( "pen - pen package subprograms" );
     New_Line;
     Put_Line( "  set_rect(r, l, t, r, b)   b := is_empty_rect( r )  offset_rect( r, dx, dy )" );
     Put_Line( "  inset_rect( r, dx, dy )   intersect_rect( r,r1,r2) b := inside_rect( ir, or )");
     Put_Line( "  b := in_rect( x, y, r )                                                     ");
     New_Line;
     Put_Line( "  frame_ellipse( id, r )    frame_rect( id, r )      fill_ellipse( id, r )    ");
     Put_Line( "  paint_rect( id, r )       fill_rect(id,rct,r,g,b)  fill_rect(id,r,cn)       ");
     Put_Line( "  line_to( id, x, y )       line( id, dx, dy )       hline( id, x1, x2, y )   ");
     Put_Line( "  vline( id, x, y1, y2 )    move_to( id, x, y )      move( id, dx, dy )       ");
     Put_Line( "  clear                     clear( r, g, b)          clear( cn )              ");
     New_Line;
     Put_Line( "  get_pen_mode( id )        get_pen_brush( id )      set_pen_ink(id,r,g,b)    " );
     Put_Line( "  set_pen_ink(id,cn)        set_pen_mode( id, m)     set_pen_pattern( id,pid) " );
     Put_Line( "  set_pen_brush( id,brush )                                                   ");
     Put_Line( "  p := greyscale( r,g,b) blend(r1,g1,b1,r2,g2,b2,r,g,b) fade(r1,g1,b1,p,r,g,b)");
     New_Line;
     Put_Line( "  new_canvas(h,v,c,id) new_screen_canvas(h,v,c,id) new_window_canvas(h,v,c,id)");
     Put_Line( "  close_canvas( id )        wait_to_reveal( id )     reveal( id )             ");
     Put_Line( "  reveal_now( id )                                                            ");
  elsif helpTopic = "step" then
     Put_Line( "step - on --break breakout, run one instruction and stop" );
     Put_Line( "  " & bold( "step" ) );
  elsif helpTopic = "strings" then
     Put_Line( "strings - strings package functions" );
     New_Line;
     Put_Line( "  element( s, i )           slice( s, l, h )         index( s, p [, d] )" );
     Put_Line( "  index_non_blank( s [,d] ) count( s, p )            replace_slice( s, l, h, b )");
     Put_Line( "  insert( s, b, n )         overwrite( s, p, n )     delete( s, l, h )" );
     Put_Line( "  trim( s , e )             head( s, c [, p] )       tail( s, c [, p] )" );
     Put_Line( "  length( s )               match( e, s )            glob( e, s ) " );
     Put_Line( "  image( s )                val( n )                 field( s, c [, d] ) " );
     Put_Line( "  mktemp( p )               lookup( s, t, d )        replace( s,f, t [,d] )" );
     Put_Line( "  csv_field( s, c [,d] )    is_typo_of( s1, s2 )     csv_replace( s,f,t [,d] )" );
     Put_Line( "  to_lower( s )             to_upper( s )            to_proper( s )" );
     Put_Line( "  to_basic( s )             to_escaped( s )          split( s,l,r,n)" );
     Put_Line( "  is_slashed_date( s )      is_control( s )          is_graphic( s ) " );
     Put_Line( "  is_letter( s )            is_lower( s )            is_upper( s ) " );
     Put_Line( "  is_basic( s )             is_digit( s )            is_hexadecimal_digit( s )" );
     Put_Line( "  is_alphanumeric( s )      is_special( s )          is_fixed( s ) " );
     Put_Line( "  unbounded_slice( s, l, h ) set_unbounded_string( s, u ) " );
     discardUnusedIdentifier( token );
  elsif helpTopic = "variables" then
     Put_Line( "Variables" );
     Put_Line( "  var [,var2...] : [" & bold( "constant" ) & "] type " &
       "[ := expression ] - declaration" );
     Put_Line( "  var : [" & "] array( " &
       "low..high) of item-type [ := array | (item,...) ] - arrays" );
     Put_Line( "  var := expression - assignment" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "?" then
     Put_Line( "? - put_line to standard output" );
     Put_Line( "  ? expression" );
  else

     declare
       scriptState : aScriptState;
       firstLine   : aliased unbounded_string;
       exprVal     : unbounded_string;
       info        : unbounded_string;
       genDate     : unbounded_string;
       -- not really in another script but we'll be safe...
       last_tag    : unbounded_string;
     begin
       saveScript( scriptState );
       if isExecutingCommand or Syntax_Check then
          scriptFilePath := helpTopic;                     -- script name
          scriptFile := open( to_string( scriptFilePath ) & ASCII.NUL, 0, 660 ); -- open script
          if scriptFile < 1 then                           -- error?
             scriptFilePath := scriptFilePath & ".bush";   -- try name with ".bush"
             scriptFile := open( to_string( scriptFilePath ) & ASCII.NUL, 0, 660 );
          end if;
          if scriptFile > 0 then                           -- good?
             error_found := false;                         -- no error found
             exit_block := false;                          -- not exit-ing a block
             if not LineRead( firstLine'access ) then        -- read first line
                put_line( standard_error, "unable to read first line of script" );
                error_found := true;
             end if;
             if script = null then
                if verboseOpt then
                   Put_Trace( "Compiling Byte Code" );
                end if;
                compileScript( firstline );
            end if;
          else
           -- try manual entries
            Put_Line( "Not a BUSH command or script...trying manual entries" );
            delay 2.0;
            declare
              status : integer;
            begin
              status := linux_system( "man "& to_string( helpTopic ) & ASCII.NUL );
            end;
          end if;
       end if;
       if scriptFile > 0 then                      -- file open
          genDate := to_unbounded_string( integer'image( day( ada.calendar.clock ) ) );
          delete( genDate, 1, 1 );
          genDate := integer'image( month( ada.calendar.clock ) )& "-" & genDate;
          delete( genDate, 1, 1 );
          genDate := integer'image( ada.calendar.year( clock ) ) & "-" & genDate;
          delete( genDate, 1, 1 );
          if HTMLoutput then
             put_line( "<p><u><b>File</b>: " & to_string( scriptFilePath ) & "</u></p><p>" );
          elsif MANOutput then
             put_line( "./" & ASCII.Quotation & "man page " & to_string( scriptFilePath ) & ".9" );
             put_line( ".TH " & ASCII.Quotation & to_string( scriptFilePath ) & ASCII.Quotation &
                 " 9 " &
                 ASCII.Quotation & to_string( genDate ) & ASCII.Quotation & " " &
                 ASCII.Quotation & "Company" & ASCII.Quotation & " " &
                 ASCII.Quotation & "Manual" & ASCII.Quotation );
          else
             Put_Line( "Help for script " & bold( to_string( scriptFilePath ) ) & ":" );
             New_Line;
          end if;
          -- lineno := 1;                             -- prepare to read it
          inputMode := fromScriptFile;             -- running a script
          error_found := false;                    -- no error found
          exit_block := false;                     -- not exit-ing a block
          cmdpos := firstScriptCommandOffset;
          token := identifiers'first;                -- dummy, replaced by g_n_t
          while (not error_found and not done and token /= eof_t) loop
             getNextToken;                            -- load first token
             if token = pragma_t then
                getNextToken;
                if identifiers( token ).name = "annotate" then
                   discardUnusedIdentifier( token );
                   getNextToken;
                   if token = symbol_t and identifiers( token ).value = "(" then
                      getNextToken;
                      if identifiers( token ).name = to_unbounded_string( "author" ) then
                         if last_tag = "author" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Author</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH AUTHOR" );
                         else
                            info := to_unbounded_string( "Author: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "created" ) then
                         if last_tag = "created" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Created</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH CREATED" );
                         else
                            info := to_unbounded_string( "Created: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "description" ) then
                         if last_tag = "description" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Description</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH DESCRIPTION" );
                         else
                            info := to_unbounded_string( "Description: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "errors" ) then
                         if last_tag = "errors" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Errors</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH ERRORS" );
                         else
                            info := to_unbounded_string( "Errors: " );
                        end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "modified" ) then
                         if last_tag = "modified" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Modified</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH MODIFIED" );
                         else
                            info := to_unbounded_string( "Modified: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "param" ) then
                         if last_tag = "param" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Param</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH PARAM" );
                         else
                            info := to_unbounded_string( "Param: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "return" ) then
                         if last_tag = "return" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Return</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH RETURN" );
                         else
                            info := to_unbounded_string( "Return: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "see also" ) then
                         if last_tag = "see also" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>See Also</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH SEE ALSO" );
                         else
                            info := to_unbounded_string( "See Also: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "summary" ) then
                         if last_tag = "summary" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Summary</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH SUMMARY" );
                         else
                            info := to_unbounded_string( "Summary: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      elsif identifiers( token ).name = to_unbounded_string( "version" ) then
                         if last_tag = "version" then
                            info := null_unbounded_string;
                         elsif HTMLOutput then
                            info := to_unbounded_string( "</p><p><b>Version</b>: " );
                         elsif MANOutput then
                            info := to_unbounded_string( ".SH VERSION" );
                         else
                            info := to_unbounded_string( "Version: " );
                         end if;
                         last_tag := identifiers( token ).name;
                         discardUnusedIdentifier( token );
                         getNextToken;
                         expect( symbol_t, "," );
                      else
                         info := null_unbounded_string;
                      end if;
                      if HTMLoutput then
                         if length( identifiers( token ).value ) = 0 then
                            info := info & "<br>&nbsp;";
                         end if;
                         info := info & identifiers( token ).value & "<br>";
                      elsif MANoutput then
                         if length( identifiers( token ).value ) = 0 then
                            info := info & ASCII.LF & ".PP";
                         end if;
                         if length( info ) > 0 then
                            put_line( info );
                         end if;
                         info := identifiers( token ).value;
                      else
                         info := info & identifiers( token ).value;
                      end if;
                      expect( strlit_t );
                      put_line( to_string( info ) );
                      expect( symbol_t, ")" ); -- getNextToken;
                   end if;
                end if;
             end if;
             discardUnusedIdentifier( token );
          end loop;
          if HTMLoutput then
             put_line( "</p><p><i>Generated " & to_string( genDate ) & "</i><br></p>" );
          end if;
        end if;
        close( scriptFile );
        restoreScript( scriptState );
     end;
     discardUnusedIdentifier( token );
  end if;
-- getNextToken;
end help;

end builtins;

