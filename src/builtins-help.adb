------------------------------------------------------------------------------
-- Built-in Shell Commands (Help)                                           --
--                                                                          --
-- Part of SparForte                                                        --
------------------------------------------------------------------------------
--                                                                          --
--            Copyright (C) 2001-2017 Free Software Foundation              --
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

with interfaces.c,
     ada.text_io,
     ada.strings.unbounded.text_io,
     ada.strings.fixed,
     ada.calendar,
     spar_os,
     string_util,
     world,
     user_io,
     script_io,
     reports.help,
     jobs,
     compiler,
     parser_db,
     parser_mysql,
     parser_teams,
     parser;  -- for pragma annotate
use  interfaces.c,
     ada.text_io,
     ada.strings.unbounded.text_io,
     ada.strings.fixed,
     ada.calendar,
     spar_os,
     string_util,
     world,
     jobs,
     user_io,
     script_io,
     reports,
     reports.help,
     compiler,
     parser_db,
     parser_mysql,
     parser_teams,
     parser;  -- for pragma annotate

package body builtins.help is

-- for help command
  HTMLOutput    : boolean := false;
  MANOutput     : boolean := false;
  LicenseOutput : boolean := false;
  TodoOutput    : boolean := false;
  CollabOutput  : boolean := false;

-- Scan and script and provide help

     procedure DoScriptHelp( helpTopic : unbounded_string ) is
       scriptState : aScriptState;
       firstLine   : aliased unbounded_string;
       exprVal     : unbounded_string;
       info        : unbounded_string;
       genDate     : unbounded_string;
       -- not really in another script but we'll be safe...
       last_tag    : unbounded_string;
       closeResult : int;

       -- to-do's
       todoTotal                : natural := 0;
       workMeasureCntUnknown    : natural := 0;
       workMeasureCntHours      : natural := 0;
       workMeasureCntFpoints    : natural := 0;
       workMeasureCntSpoints    : natural := 0;
       workMeasureCntSloc       : natural := 0;
       workMeasureCntSizeS      : natural := 0;
       workMeasureCntSizeM      : natural := 0;
       workMeasureCntSizeL      : natural := 0;
       workMeasureCntSizeXL     : natural := 0;
       workPriorityCntUnknown   : natural := 0;
       workPriorityCntLevelL    : natural := 0;
       workPriorityCntLevelM    : natural := 0;
       workPriorityCntLevelH    : natural := 0;
       workPriorityCntSeverity1 : natural := 0;
       workPriorityCntSeverity2 : natural := 0;
       workPriorityCntSeverity3 : natural := 0;
       workPriorityCntSeverity4 : natural := 0;
       workPriorityCntSeverity5 : natural := 0;
       workPriorityCntRisk      : natural := 0;
       workPriorityCntCVSSMinor : natural := 0;
       workPriorityCntCVSSMajor : natural := 0;
       workPriorityCntCVSSCrit  : natural := 0;
       workPriorityCompleted    : natural := 0;
       measure : identifier;
       units   : unbounded_string;

       -- repeatedly used strings, converted to unbounded_strings

       advise_str   : constant unbounded_string := to_unbounded_string( "advise" );
       license_str  : constant unbounded_string := to_unbounded_string( "license" );
       todo_str     : constant unbounded_string := to_unbounded_string( "todo" );
       blocked_str  : constant unbounded_string := to_unbounded_string( "blocked" );
       clarify_str  : constant unbounded_string := to_unbounded_string( "clarify" );
       dispute_str  : constant unbounded_string := to_unbounded_string( "dispute" );
       propose_str  : constant unbounded_string := to_unbounded_string( "propose" );
       annotate_str : constant unbounded_string := to_unbounded_string( "annotate" );
       refactor_str : constant unbounded_string := to_unbounded_string( "refactor" );

       --authorId     : identifier := eof_t;

       function ParsePragmaKindAsHelp return unbounded_string is
          pragmaKind : unbounded_string;
       begin
          pragmaKind := identifiers( token ).name;
          discardUnusedIdentifier( token );
          getNextToken;
          return pragmaKind;
       end ParsePragmaKindAsHelp;

       procedure ParsePragmaStatementAsHelp( pragmaKind : unbounded_string ) is
         exprVal  : unbounded_string;
         exprType : identifier;
       begin
         if pragmaKind = license_str then
            if token = symbol_t and identifiers( token ).value.all = "(" then
               getNextToken;
               info := identifiers( token ).name;
               discardUnusedIdentifier( token );
               getNextToken;
               if token = symbol_t and identifiers( token ).value.all = "," then
                  expect( symbol_t, "," );
                  info := info & ": " & identifiers( token ).value.all;
                  expect( strlit_t );
               end if;
               expect( symbol_t, ")" );
               if LicenseOutput then
                  put_line( to_string( info ) );
               end if;
            end if;
         elsif pragmaKind = todo_str then
            if token = symbol_t and identifiers( token ).value.all = "(" then
               todoTotal := todoTotal + 1;
               getNextToken;
               info := identifiers( token ).name; -- name
               getNextToken;
               expect( symbol_t, "," );
               ParseStaticExpression( exprVal, exprType );
               info := info & "," & ToCSV( exprVal ); -- message
               expect( symbol_t, "," );
               info := info & "," & identifiers( token ).name; -- measure
               measure := token;
               getNextToken;
               expect( symbol_t, "," );
               info := info & "," & identifiers( token ).value.all; -- unit
               units := identifiers( token ).value.all;
               -- calculate work by measure
               if measure = teams_work_measure_unknown_t then
                  workMeasureCntUnknown := workMeasureCntUnknown + 1;
               elsif measure = teams_work_measure_hours_t then
                  workMeasureCntHours   := workMeasureCntHours + natural( to_numeric( units ) );
               elsif measure = teams_work_measure_fpoints_t then
                  workMeasureCntFpoints := workMeasureCntFpoints + natural( to_numeric( units ) );
               elsif measure = teams_work_measure_spoints_t then
                  workMeasureCntSpoints := workMeasureCntSpoints + natural( to_numeric( units ) );
               elsif measure = teams_work_measure_sloc_t then
                  workMeasureCntSloc    := workMeasureCntSloc + natural( to_numeric( units ) );
               elsif measure = teams_work_measure_size_t and units = "s" then
                  workMeasureCntSizeS   := workMeasureCntSizeS + 1;
               elsif measure = teams_work_measure_size_t and units = "m" then
                  workMeasureCntSizeM   := workMeasureCntSizeM + 1;
               elsif measure = teams_work_measure_size_t and units = "l" then
                  workMeasureCntSizeL   := workMeasureCntSizeL + 1;
               elsif measure = teams_work_measure_size_t and units = "xl" then
                  workMeasureCntSizeXL   := workMeasureCntSizeXL + 1;
               else
                  null; -- DEBUG
               end if;
               getNextToken;
               expect( symbol_t, "," );
               info := info & "," & identifiers( token ).name; -- priority
               measure := token;
               getNextToken;
               expect( symbol_t, "," );
               info := info & "," & identifiers( token ).value.all; -- unit
               units := identifiers( token ).value.all;
               if measure = teams_work_priority_unknown_t then
                  workPriorityCntUnknown := workPriorityCntUnknown + 1;
               elsif measure = teams_work_priority_level_t and units = "l" then
                  workPriorityCntLevelL := workPriorityCntLevelL + 1;
               elsif measure = teams_work_priority_level_t and units = "m" then
                  workPriorityCntLevelM := workPriorityCntLevelM + 1;
               elsif measure = teams_work_priority_level_t and units = "h" then
                  workPriorityCntLevelH := workPriorityCntLevelH + 1;
               elsif measure = teams_work_priority_severity_t and units = " 1" then
                  workPriorityCntSeverity1 := workPriorityCntSeverity1 + 1;
               elsif measure = teams_work_priority_severity_t and units = " 2" then
                  workPriorityCntSeverity2 := workPriorityCntSeverity2 + 1;
               elsif measure = teams_work_priority_severity_t and units = " 3" then
                  workPriorityCntSeverity3 := workPriorityCntSeverity3 + 1;
               elsif measure = teams_work_priority_severity_t and units = " 4" then
                  workPriorityCntSeverity4 := workPriorityCntSeverity4 + 1;
               elsif measure = teams_work_priority_severity_t and units = " 5" then
                  workPriorityCntSeverity5 := workPriorityCntSeverity5 + 1;
               elsif measure = teams_work_priority_risk_t then
                  workPriorityCntRisk := workPriorityCntRisk + natural( to_numeric( units ) );
               elsif measure = teams_work_priority_completed_t then
                  workPriorityCompleted := workPriorityCompleted + 1;
               elsif measure = teams_work_priority_cvss_t then
                  declare
                    u : long_float;
                  begin
                    u := to_numeric( units );
                    if u < 4.0 then
                      workPriorityCntCVSSMinor := workPriorityCntCVSSMinor + 1;
                    elsif u < 7.0 then
                      workPriorityCntCVSSMajor := workPriorityCntCVSSMajor + 1;
                    else
                      workPriorityCntCVSSCrit  := workPriorityCntCVSSCrit  + 1;
                    end if;
                  end;
               else
                  null; -- DEBUG
               end if;
               getNextToken;
               -- ticket is optional
               if token = symbol_t and identifiers( token ).value.all = "," then
                  expect( symbol_t, "," );
                  info := info & "," & ToCSV( identifiers( token ).value.all );
                  getNextToken;
               end if;
               expect( symbol_t, ")" );
               if TodoOutput then
                  put_line( to_string( info ) );
               end if;
            end if;
         elsif pragmaKind = advise_str or
               pragmaKind = blocked_str or
               pragmaKind = clarify_str or
               pragmaKind = dispute_str or
               pragmaKind = propose_str or
               pragmaKind = refactor_str then
            if token = symbol_t and identifiers( token ).value.all = "(" then
               getNextToken;
               info := pragmaKind & "," & identifiers( token ).name; -- name
               getNextToken;
               expect( symbol_t, "," );
               info := info & "," & identifiers( token ).name; -- name
               getNextToken;
               expect( symbol_t, "," );
               ParseStaticExpression( exprVal, exprType );
               info := info & "," & ToCSV( exprVal ); -- message
               expect( symbol_t, ")" );
               if CollabOutput then
                  put_line( to_string( info ) );
               end if;
            end if;
         elsif pragmaKind = annotate_str then
            if token = symbol_t and identifiers( token ).value.all = "(" then
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
                  -- handle a teams.member variable for an author
                  -- declarations don't happen so this doesn't work.
                  --if token /= strlit_t then
                  --   if identifiers( token ).class = VarClass then
                  --      if getBaseType( identifiers( token ).kind ) = teams_member_t then
                  --         ParseIdentifier( authorId );
                  --      end if;
                  --   end if;
                  --end if;
               elsif identifiers( token ).name = to_unbounded_string( "bugs" ) then
                  if last_tag = "bugs" then
                     info := null_unbounded_string;
                  elsif HTMLOutput then
                     info := to_unbounded_string( "</p><p><b>Bugs</b>: " );
                  elsif MANOutput then
                     info := to_unbounded_string( ".SH BUGS" );
                  else
                     info := to_unbounded_string( "Bugs: " );
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
               elsif identifiers( token ).name = to_unbounded_string( "category" ) then
                  if last_tag = "category" then
                     info := null_unbounded_string;
                  elsif HTMLOutput then
                     info := to_unbounded_string( "</p><p><b>Category</b>: " );
                  elsif MANOutput then
                     info := to_unbounded_string( ".SH CATEGORY" );
                  else
                     info := to_unbounded_string( "Category: " );
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
               elsif identifiers( token ).name = to_unbounded_string( "see_also" ) then
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
               elsif identifiers( token ).name = to_unbounded_string( "todo" ) then
                  if last_tag = "todo" then
                      info := null_unbounded_string;
                  elsif HTMLOutput then
                      info := to_unbounded_string( "</p><p><b>To Do</b>: " );
                  elsif MANOutput then
                      info := to_unbounded_string( ".SH TODO" );
                  else
                      info := to_unbounded_string( "To Do: " );
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
               --if authorId = eof_t then
                  ParseStaticExpression( exprVal, exprType );
               --else
                  -- don't let it carry over for multiple authors
               --   authorId := eof_t;
               --end if;
               --ParseStaticExpression( exprVal, exprType );
               if HTMLoutput then
                  if length( exprVal ) = 0 then
                     info := info & "<br>&nbsp;";
                  end if;
                  info := info & exprVal & "<br>";
               elsif MANoutput then
                  if length( exprVal ) = 0 then
                     info := info & ASCII.LF & ".PP";
                  end if;
                  if length( info ) > 0 then
                      -- if it's not a license, output the annotations
                      if not LicenseOutput then
                         put_line( info );
                      end if;
                  end if;
                  info := exprVal;
               else
                  info := info & exprVal;
               end if;
               -- if it's not a license, output the annotations
               if not LicenseOutput then
                  put_line( to_string( info ) );
               end if;
               expect( symbol_t, ")" ); -- getNextToken;
            end if;
         else
            -- Any other pragma skip to the ; or @ at the end
            loop
              exit when token = symbol_t and identifiers( token ).value.all = to_unbounded_string( ";" );
              exit when token = symbol_t and identifiers( token ).value.all = to_unbounded_string( "@" );
              exit when error_found or done or token = eof_t;
              getNextToken;
            end loop;
         end if;
       end ParsePragmaStatementAsHelp;

       procedure ParsePragmaAsHelp is
         pragmaKind : unbounded_string;
       begin
         expect( pragma_t );
         if token = is_t then
            -- a pragma block
            expect( is_t );
            -- examine the name of the pragma and return a pragma kind matching the
            -- name
            pragmaKind := parsePragmaKindAsHelp;
            while token /= eof_t and token /= end_t loop
               -- an error check
               ParsePragmaStatementAsHelp( pragmaKind );
               if token = symbol_t and identifiers( symbol_t ).value.all = to_unbounded_string( "@" ) then
                  expect( symbol_t, "@" );
               elsif token = symbol_t and identifiers( symbol_t ).value.all = to_unbounded_string( ";" ) then
                  expect( symbol_t, ";" );
                  if token /= end_t then
                     pragmaKind := parsePragmaKindAsHelp;
                  end if;
               else
                  err( "'@' or ';' expected" );
               end if;
            end loop;
            expect( end_t );
            expect( pragma_t );
         else
            -- A single pragma
            pragmaKind := parsePragmaKindAsHelp;
            loop
               ParsePragmaStatementAsHelp( pragmaKind );
               exit when done or token = eof_t or (token = symbol_t and identifiers( symbol_t ).value.all /= to_unbounded_string( "@" ) );
               expect( symbol_t, "@" );
            end loop;
         end if;
       end ParsePragmaAsHelp;

     begin
       saveScript( scriptState );
       if isExecutingCommand or Syntax_Check then
          scriptFilePath := helpTopic;                     -- script name
<<retry1>> scriptFile := open( to_string( scriptFilePath ) & ASCII.NUL, 0, 660 ); -- open script
          if scriptFile < 1 then                           -- error?
             if C_errno = EINTR then
                goto retry1;
             end if;
<<retry2>>   scriptFile := open( to_string( scriptFilePath ) & ".sp" & ASCII.NUL, 0, 660 );
             if scriptFile > 0 then
                if C_errno = EINTR then
                   goto retry2;
                end if;
                scriptFilePath := scriptFilePath & ".sp"  ;
             end if;
          end if;
          if scriptFile < 1 then                           -- error?
<<retry3>>   scriptFile := open( to_string( scriptFilePath ) & ".bush" & ASCII.NUL, 0, 660 );
             if scriptFile > 0 then
                if C_errno = EINTR then
                   goto retry3;
                end if;
                scriptFilePath := scriptFilePath & ".bush"  ;
             end if;
          end if;
          if scriptFile > 0 then                           -- good?
             error_found := false;                         -- no error found
             exit_block := false;                          -- not exit-ing a block
             if not LineRead( firstLine'access ) then        -- read first line
                err( "help command is unable to read first line of script" );
             end if;
             if script = null then
                if verboseOpt then
                   Put_Trace( "Compiling Byte Code" );
                end if;
                compileScript( firstline );
            end if;
          else
           -- try manual entries
            Put_Line( "Not a SparForte command or script...trying manual entries" );
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
          elsif LicenseOutput then
             null;
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

          -- search the script for pragmas, interpreting the results
          -- as necessary for the help command

          while (not error_found and not done and token /= eof_t) loop
             getNextToken;                            -- load first token
             if token = pragma_t then
                ParsePragmaAsHelp;
             end if;
          end loop;

          if HTMLoutput then
             put_line( "</p><p><i>Generated " & to_string( genDate ) & "</i><br></p>" );
          elsif TodoOutput then
             -- produce summary
             if todoTotal > 0 then
                new_line;
                put_line( "Amount of Work" );
                new_line;
                if workMeasureCntUnknown > 0 then
                   put_line( "Unknown:" & workMeasureCntUnknown'img );
                end if;
                if workMeasureCntHours > 0 then
                   put_line( "Hours:" & workMeasureCntHours'img );
                end if;
                if workMeasureCntFpoints > 0 then
                   put_line( "Function Points:" & workMeasureCntFpoints'img );
                end if;
                if workMeasureCntSpoints > 0 then
                   put_line( "Story Points:" & workMeasureCntSpoints'img );
                end if;
                if workMeasureCntSloc > 0 then
                   put_line( "Lines-of-Code:" & workMeasureCntSloc'img );
                end if;
                if workMeasureCntSizeS > 0 then
                   put_line( "Small:" & workMeasureCntSizeS'img );
                end if;
                if workMeasureCntSizeM > 0 then
                   put_line( "Medium:" & workMeasureCntSizeM'img );
                end if;
                if workMeasureCntSizeL > 0 then
                   put_line( "Large:" & workMeasureCntSizeL'img );
                end if;
                if workMeasureCntSizeXL > 0 then
                   put_line( "Extra Large:" & workMeasureCntSizeXL'img );
                end if;

                new_line;
                put_line( "Priorities of  Work" );
                new_line;
                if workPriorityCntUnknown > 0 then
                   put_line( "Unknown:" & workPriorityCntUnknown'img );
                end if;
                if workPriorityCompleted > 0 then
                   put_line( "Completed:" & workPriorityCompleted'img );
                end if;
                if workPriorityCntLevelL > 0 then
                   put_line( "Low:" & workPriorityCntLevelL'img );
                end if;
                if workPriorityCntLevelM > 0 then
                   put_line( "Medium:" & workPriorityCntLevelM'img );
                end if;
                if workPriorityCntLevelH > 0 then
                   put_line( "High:" & workPriorityCntLevelH'img );
                end if;
                if workPriorityCntSeverity1 > 0 then
                   put_line( "Severity 1:" & workPriorityCntSeverity1'img );
                end if;
                if workPriorityCntSeverity2 > 0 then
                   put_line( "Severity 2:" & workPriorityCntSeverity2'img );
                end if;
                if workPriorityCntSeverity3 > 0 then
                   put_line( "Severity 3:" & workPriorityCntSeverity3'img );
                end if;
                if workPriorityCntSeverity4 > 0 then
                   put_line( "Severity 4:" & workPriorityCntSeverity4'img );
                end if;
                if workPriorityCntSeverity5 > 0 then
                   put_line( "Severity 5:" & workPriorityCntSeverity5'img );
                end if;
                if workPriorityCntRisk > 0 then
                   put_line( "Risk:" & workPriorityCntRisk'img );
                end if;
                if workPriorityCntCVSSMinor > 0 then
                   put_line( "CVSS Minor:" & workPriorityCntCVSSMinor'img );
                end if;
                if workPriorityCntCVSSMajor > 0 then
                   put_line( "CVSS Major:" & workPriorityCntCVSSMajor'img );
                end if;
                if workPriorityCntCVSSCrit > 0 then
                   put_line( "CVSS Critical:" & workPriorityCntCVSSCrit'img );
                end if;

                new_line;
                put_line( "Number of To-Do Items:" & todoTotal'img );
             else
                put_line( "No todo's found" );
             end if;
          end if;
        end if;
<<retryclose>> closeResult := close( scriptFile );
        if closeResult < 0 then
           if C_errno = EINTR then
              goto retryclose;
           end if;
        end if;
        restoreScript( scriptState );
        discardUnusedIdentifier( token );
     end DoScriptHelp;

-----------------------------------------------------------------------------
--   HELP (POSIX SHELL COMMAND)
-- Syntax: help = help [ ident ]
-- Source: SparForte built-in
-----------------------------------------------------------------------------
-- Help is broken up into sub-procedures due to its large size.

procedure helpMain is
  e : aHelpEntry;
  r : aRootReportPtr;
  l : helpList.List;
begin
   r := new longHelpReport;
   start( r.all );
   startHelp( e, "help" );
   summary( e, "SparForte command prompt help" );
   category( e, "built-in commands" );
   description( e,
     "The help command gives short advice on keywords, packages, " &
     "scripts, operating system commands and other topics.  Enter 'help' and " &
     "a topic to get advice.  For example, 'help arrays' briefly explains " &
     "the arrays package. These are the internal topics:" );
   content( e, "arrays" );
   content( e, "calendar" );
   content( e, "case" );
   content( e, "cd" );
   content( e, "cgi" );
   content( e, "chains" );
   content( e, "clear" );
   content( e, "close" );
   content( e, "command_line" );
   content( e, "create" );
   content( e, "db" );
   content( e, "dbm" );
   content( e, "declare" );
   content( e, "delay" );
   content( e, "delete" );
   content( e, "directory_operations" );
   content( e, "doubly_linked_lists" );
   content( e, "dynamic_hash_tables" );
   content( e, "end_of_file" );
   content( e, "end_of_line" );
   content( e, "btree_io" );
   content( e, "enums" );
   content( e, "env" );
   content( e, "exceptions" );
   content( e, "exit" );
   content( e, "expressions" );
   content( e, "files" );
   content( e, "for" );
   content( e, "function" );
   content( e, "get" );
   content( e, "get_immediate" );
   content( e, "get_line" );
   content( e, "gnat.cgi" );
   content( e, "gnat.crc32" );
   content( e, "hash_io" );
   content( e, "history" );
   content( e, "if" );
   content( e, "inkey" );
   content( e, "is_open" );
   content( e, "jobs" );
   content( e, "keys" );
   content( e, "line" );
   content( e, "loop" );
   content( e, "memcache" );
   content( e, "mode" );
   content( e, "mysql" );
   content( e, "mysqlm" );
   content( e, "name" );
   content( e, "new_line" );
   content( e, "null" );
   content( e, "numerics" );
   content( e, "open" );
   content( e, "os" );
   content( e, "pen" );
   content( e, "pragma" );
   content( e, "procedure" );
   content( e, "put" );
   content( e, "put_line" );
   content( e, "raise" );
   content( e, "reset" );
   content( e, "records" );
   content( e, "return" );
   content( e, "skip_line" );
   content( e, "sound" );
   content( e, "source_info" );
   content( e, "stats" );
   content( e, "step" );
   content( e, "strings" );
   content( e, "strings.match" );
   content( e, "subtype" );
   content( e, "System" );
   content( e, "teams" );
   content( e, "templates" );
   content( e, "trace" );
   content( e, "type" );
   content( e, "typeset" );
   content( e, "units" );
   content( e, "unset" );
   content( e, "variables" );
   content( e, "wait" );
   content( e, "while" );
   content( e, ASCII.Quotation & "?" & ASCII.Quotation );
   footer( e, "For full details, see the SparForte documentation.  To leave " &
     "SparForte, enter 'return' (or 'logout' if this is your login session)." );
   endHelp( e );
   render( longHelpReport( r.all ), e ); -- TODO: fix typecast

   finish( r.all );
end helpMain;

procedure helpBtreeIO is
begin
     Put_Line( "btree_io (package) - Berkeley DB B-tree files" );
     New_Line;
     Put_Line( "add( f, k, v )                   get_previous( f, c, k, v )" );
     Put_Line( "append( f, k, v )                b := has_element( f, k )" );
     Put_Line( "clear( f )                       increment( f, k [,n] )" );
     Put_Line( "close( f )                       b := is_open( f )" );
     Put_Line( "close_cursor( f, c )             e := last_error( f )" );
     Put_Line( "create( f, p, kl, vl )           open( f, p, kl, vl )" );
     Put_Line( "decrement( f, k [,n] )           open_cursor( f, c )" );
     Put_Line( "delete( f )                      prepend( f, k, v )" );
     Put_Line( "flush( f )                       raise_exceptions( f, b )" );
     Put_Line( "v := get( f, k )                 remove( f, k )" );
     Put_Line( "get_first( f, c, k, v )          replace( f, k, v )" );
     Put_Line( "get_last( f, c, k, v )           set( f, k, v )" );
     Put_Line( "get_next( f, c, k, v )           truncate( f )" );
     Put_Line( "                                 b := will_raise( f )" );
end helpBtreeIO;

procedure helpDb is
begin
     Put_Line( "db (package) - APQ PostgreSQL database package interface" );
     New_Line;
     Put_Line( "  db.connect( d [, u, w ][, h][, p] )" );
     Put_Line( "  append( s [,a] )            prepare( s [, a] )" );
     Put_Line( "  append_line( s )            append_quoted( s )" );
     Put_Line( "  execute                     execute_checked( [ s ] )" );
     Put_Line( "  disconnect                  b := is_connected" );
     Put_Line( "  reset                       s := error_message" );
     Put_Line( "  s := notice_message         s := in_abort_state" );
     Put_Line( "  s := options                set_rollback_on_finalize( b )" );
     Put_Line( "  open_db_trace( f [,m] )     b := will_rollback_on_finalize" );
     Put_Line( "  close_db_trace              set_trace( b )" );
     Put_Line( "  b := is_trace               clear" );
     Put_Line( "  raise_exceptions( [ b ] )   report_errors( b )" );
     Put_Line( "  begin_work                  rollback_work" );
     Put_Line( "  commit_work                 rewind" );
     Put_Line( "  fetch [ (i) ]               b := end_of_query" );
     Put_Line( "  t := tuple                  n := tuples" );
     Put_Line( "  n := columns                s := column_name( c )" );
     Put_Line( "  i := column_index( s )      b := is_null( c )" );
     Put_Line( "  s := value( c )             d := engine_of" );
     Put_Line( "  show                        list" );
     Put_Line( "  schema( t )                 users" );
     Put_Line( "  databases" );
end helpDb;

procedure helpDbm is
begin
     Put_Line( "dbm (package) - APQ PostgreSQL database package - multiple connections interface" );
     New_Line;
     Put_line( "connect( c, d [, u, w ][, h][, p] )" );
     Put_line( "append( q, s [, a] )         prepare( q, s [, a] )" );
     Put_line( "append_line( q, s )          append_quoted( q, c, s )" );
     Put_line( "execute( q, c )              execute_checked( q, c [, s ] )" );
     Put_line( "disconnect( c )              is_connected( c )" );
     Put_line( "reset( c )                   s := error_message( c )" );
     Put_line( "databases( c )               b := in_abort_state( c )" );
     Put_line( "s := options( c )            set_rollback_on_finalize( c, b )" );
     Put_line( "open_db_trace( c, f [, m] )  b := will_rollback_on_finalize( c )" );
     Put_line( "close_db_trace( c )          set_trace( c, b )" );
     Put_line( "b := is_trace( c )           clear( q )" );
     Put_line( "raise_exceptions( q [, b ] ) report_errors( q, b )" );
     Put_line( "begin_work( q, c )           rollback_work( q, c )" );
     Put_line( "commit_work( q, c )          rewind( q )" );
     Put_line( "fetch( q [, i] )             b := end_of_query( q )" );
     Put_line( "n := tuple( q, t )           n := tuples( q )" );
     Put_line( "n := columns( q )            s := column_name( q, i )" );
     Put_line( "i := column_index( q, s )    b := is_null( q, i )" );
     Put_line( "s := value( q, i )           b := engine_of( c )" );
     Put_line( "show( q, c )                 list( c )" );
     Put_line( "schema( c, t )               users( c )" );
     Put_line( "new_connection( c )          new_query( q )" );
     Put_line( "fetch_values( q, c, r )      s := notice_message( c )" );
     Put_line( "append_for_insert( q, c, r ) append_for_update( q, c, r )" );
end helpDbm;

procedure helpHashIO is
begin
     Put_Line( "hash_io (package) - Berkeley DB hash files" );
     New_Line;
     Put_Line( "add( f, k, v )                   get_previous( f, c, k, v )" );
     Put_Line( "append( f, k, v )                b := has_element( f, k )" );
     Put_Line( "clear( f )                       increment( f, k [,n] )" );
     Put_Line( "close( f )                       b := is_open( f )" );
     Put_Line( "close_cursor( f, c )             e := last_error( f )" );
     Put_Line( "create( f, p, kl, vl )           open( f, p, kl, vl )" );
     Put_Line( "decrement( f, k [,n] )           open_cursor( f, c )" );
     Put_Line( "delete( f )                      prepend( f, k, v )" );
     Put_Line( "flush( f )                       raise_exceptions( f, b )" );
     Put_Line( "v := get( f, k )                 remove( f, k )" );
     Put_Line( "get_first( f, c, k, v )          replace( f, k, v )" );
     Put_Line( "get_last( f, c, k, v )           set( f, k, v )" );
     Put_Line( "get_next( f, c, k, v )           truncate( f )" );
     Put_Line( "                                 b := will_raise( f )" );
end helpHashIO;

procedure helpMySQL is
begin
     Put_Line( "mysql (package) - APQ MySQL database package interface" );
     New_Line;
     Put_Line( "  connect( d [, u, w ][, h][, p] )" );
     Put_Line( "  append( s [, a] )           prepare( s [, a] )" );
     Put_Line( "  append_line( s )            append_quoted( s )" );
     Put_Line( "  execute                     execute_checked( [ s ] )" );
     Put_Line( "  disconnect                  is_connected" );
     Put_Line( "  reset                       s := error_message" );
     Put_Line( "  databases                   b := in_abort_state" );
     Put_Line( "  s := options                set_rollback_on_finalize( b )" );
     Put_Line( "  open_db_trace( f [,m] )     b := will_rollback_on_finalize" );
     Put_Line( "  close_db_trace              set_trace( b )" );
     Put_Line( "  b := is_trace               clear" );
     Put_Line( "  raise_exceptions( [ b ] )   report_errors( b )" );
     Put_Line( "  begin_work                  rollback_work" );
     Put_Line( "  commit_work                 rewind" );
     Put_Line( "  fetch [ (i) ]               b := end_of_query" );
     Put_Line( "  n := tuple( t )             n := tuples" );
     Put_Line( "  n := columns                s := column_name( c )" );
     Put_Line( "  i := column_index( s )      b := is_null( c )" );
     Put_Line( "  s := value( c )             b := engine_of " );
     Put_Line( "  show                        list" );
     Put_Line( "  schema( t )                 users" );
end helpMySQL;

procedure helpMySQLM is
begin
     Put_Line( "mysqlm (package) - APQ MySQL database package - multiple connections interface" );
     New_Line;
     Put_Line( "  connect( c, d [, u, w ][, h][, p] )" );
     Put_Line( "  append( q, s [, a] )         prepare( q, s [, a] )" );
     Put_Line( "  append_line( q, s )          append_quoted( q, c, s )" );
     Put_Line( "  execute( q, c )              execute_checked( q, c [, s ] )" );
     Put_Line( "  disconnect( c )              is_connected( c )" );
     Put_Line( "  reset( c )                   s := error_message( c )" );
     Put_Line( "  databases( c )               b := in_abort_state( c )" );
     Put_Line( "  s := options( c )            set_rollback_on_finalize( c, b )" );
     Put_Line( "  open_db_trace( c, f [, m] )  b := will_rollback_on_finalize( c )" );
     Put_Line( "  close_db_trace( c )          set_trace( c, b )" );
     Put_Line( "  b := is_trace( c )           clear( q )" );
     Put_Line( "  raise_exceptions( q [, b ] ) report_errors( q, b )" );
     Put_Line( "  begin_work( q, c )           rollback_work( q, c )" );
     Put_Line( "  commit_work( q, c )          rewind( q )" );
     Put_Line( "  fetch( q [, i] )             b := end_of_query( q )" );
     Put_Line( "  n := tuple( q, t )           n := tuples( q )" );
     Put_Line( "  n := columns( q )            s := column_name( q, i )" );
     Put_Line( "  i := column_index( q, s )    b := is_null( q, i )" );
     Put_Line( "  s := value( q, i )           b := engine_of( c ) " );
     Put_Line( "  show( q, c )                 list( c )" );
     Put_Line( "  schema( c, t )               users( c )" );
     Put_Line( "  new_connection( c )          new_query( q )" );
     Put_Line( "  fetch_values( q, c, r )" );
     Put_Line( "  append_for_insert( q, c, r ) append_for_update( q, c, r )" );
end helpMySQLM;

procedure helpUnits is
begin
     Put_Line( "units (package) - measurement conversions:" );
     New_Line;
     Put_Line( "  r := acres2hectares( f ) r := bytes2mb( f )     r := c2f( f )" );
     Put_Line( "  r := c2k( f )            r := cm2inches( f )    r := cucm2floz( f )" );
     Put_Line( "  r := cucm2usfloz( f )    r := f2c( f )          r := feet2cm( f )" );
     Put_Line( "  r := floz2usfloz( f )    r := floz2cucm( f )    r := floz2ml( f )" );
     Put_Line( "  r := g2troz( f )         r := gal2l( f )        r := grams2oz( f )" );
     Put_Line( "  r := hectares2acres( f ) r := inches2mm( f )    r := k2c( f )" );
     Put_Line( "  r := kg2lb( f )          r := km2miles( f )     r := l2gal( f )" );
     Put_Line( "  r := l2quarts( f )       r := l2usdryoz( f )    r := l2usliqoz( f )" );
     Put_Line( "  r := lb2kg( f )          r := ly2pc( f )        r := m2yards( f )" );
     Put_Line( "  r := mb2bytes( f )       r := miles2km( f )     r := ml2floz( f )" );
     Put_Line( "  r := ml2usfloz( f )      r := mm2inches( f )    r := pc2ly( f )" );
     Put_Line( "  r := pints2l( f )        r := oz2grams( f )     r := sqcm2sqin( f )" );
     Put_Line( "  r := sqft2sqm( f )       r := sqin2sqcm( f )    r := sqkm2sqmiles( f )" );
     Put_Line( "  r := sqm2sqft( f )       r := sqm2sqyd( f )     r := sqmiles2sqkm( f )" );
     Put_Line( "  r := sqyd2sqm( f )       r := tonnes2tons( f )  r := tons2tonnes( f )" );
     Put_Line( "  r := troz2g( f )         r := usdryoz2l( f )    r := usliqoz2l( f )" );
     Put_Line( "  r := usfloz2cucm( f )    r := usfloz2floz( f )  r := usfloz2ml( f )" );
     Put_Line( "  r := yards2m( f )" );
end helpUnits;

procedure helpNumerics is
begin
     Put_Line( "numerics - numerics package constants/functions" );
     New_Line;
     Put_line( "Constants" );
     New_Line;
     Put_line( "  e                    log2_e                  log10_e             ln10" );
     Put_line( "  ln2                  pi                      pi_by_2             pi_by_4" );
     Put_line( "  pi_under_1           pi_under_2              sqrt_pi_under_2     sqrt_2" );
     Put_line( "  sqrt_2_under_1" );
     New_Line;
     Put_line( "General" );
     New_Line;
     Put_line( "  f := abs( e )               f := ceiling( e )            f := copy_sign( x, y )" );
     Put_line( "  f := even( i )              f := exp( x )                f := exponent( e )" );
     Put_line( "  f := floor( e )             f := fnv_hash_of( s, l )     f := fraction( e )" );
     Put_line( "  f := hash_of( s, l )        f := leading_part( x, y )    f := log( e [,b] )" );
     Put_line( "  f := machine( e )           f := max( x, y )             r := md5( s )" );
     Put_line( "  f := min( x, y )            f := odd( x )                f := murmur_hash_of( s, l )" );
     Put_line( "  p := pos( c )               f := random                  f := remainder( x, y )" );
     Put_line( "  r := rnd( p )               i := rotate_left( e, b )     i := rotate_right( e, b )" );
     Put_line( "  f := rounding( e )          f := scaling( x, y )         f := sdbm_hash_of( s, l )" );
     Put_Line( "  f := serial                 d := sha1_digest_of( s )     d := sha224_digest_of( s )" );
     Put_Line( "  d := sha256_digest_of( s )  d := sha512_digest_of( s )   i := shift_left( e, b )" );
     Put_Line( "  i := shift_right( e, b ) i := shift_right_arithmetic( x, b )" );
     Put_Line( "  f := sqrt( e )              f := sturges( l, h, t )      f := truncation( e )" );
     Put_Line( "  f := unbiased_rounding( e ) f := value( s )" );
     New_Line;
     Put_line( "Trig" );
     New_Line;
     Put_line( "  f := arccos( x [,cycle] )    f := arccosh( e )         f := arccot( x, y [,cycle] )" );
     Put_line( "  f := arccoth( e )            f := arcsin( e [,cycle] ) f := arcsinh( e )" );
     Put_line( "  f := arctan( x, y [,cycle] ) f := arctanh( e )         f := cos( e [,cycle] )" );
     Put_line( "  f := cosh( e )               f := cot( e [,cycle] )    f := coth( e )" );
     Put_line( "  f := sin( e [,cycle] )       f := sinh( e )            f := tan( e [,cycle] )" );
     Put_line( "  f := tanh( e )" );
     New_Line;
     Put_line( "Complex" );
     New_Line;
     Put_line( "  re( complex )                im( complex )             modulus( complex )" );
     Put_line( "  set_re( complex, r )         set_im( complex, i )      argument( complex )" );
     New_Line;
     Put_Line( "  abs( x ) is not 'numerics.abs( x )' because it's not in the numerics package" );
end helpNumerics;

procedure helpPragma is
begin
     Put_Line( "pragma - interpreter directive" );
     New_Line;
     Put_Line( "  " & bold( "pragma" ) & " " &
       "ada_95 - enforce Ada 95 restrictions" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "advise( from, to, message ) - request team advice/assistance" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "annotate( [type,]""text"" ) - embed a comment for help command" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "assert( condition ) - with --debug/--test, terminate program on condition fail" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "assumption( used, written, var ) - assume a variable was read or written to when testing" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "blocked( from, message ) - announce programmer progress blocked" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "clarify( from, to, message ) - request programmer clarification" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "debug( `commands` ) - with --debug, execute debug commands" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "depreciated/deprecated( ""newscript"" ) - report script as obsolete by newscript" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "dispute( from, to, message ) - request program review" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "export( shell | local_memcache | memcache | session , var ) - export a variable" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "export_json( shell | local_memcache | memcache | session , var )" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "gcc_errors - same as --gcc-errors" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "import( shell | cgi | local_memcache | memcache | session, var ) - import a var" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "import_json( shell | cgi | local_memcache | memcache | session, var )" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspect( var ) - perform 'env var' on --break breakout" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspection_peek - like a inspection_point but no breakout" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "inspection_point - break to command prompt if --break is used" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "license( license_name [, extra] )" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "no_command_hash - do not store command pathnames in the hash table" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "prompt_script( `commands` ) - commands to draw command prompt" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "propose( from, to, message ) - suggest a change to a program" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "refactor( from, to, message ) - request programmer optimize program" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_annotate_todos ) - " &
         "must not have annotate/todo" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( annotations_not_optional ) - " &
         "must have pragma annotate" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_auto_declarations ) - " &
         "no auto command line declarations" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_external_commands ) - " &
         "disable operating system commands" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_memcache ) - " &
         "disable connections to memcache" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_mysql_database ) - " &
         "disable connections to mysql" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_postgresql_database ) - " &
         "disable connections to postgresql" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "restriction( no_unused_identifiers ) - " &
         "stricter unused tests" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "session_export_script( `commands` ) - commands to export session variables" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "session_import_script( `commands` ) - commands to import session variables" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "software_model( model_name )" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "suppress( word_quoting ) - allow shell 'barewords'" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "suppress( all_priority_todos_for_release ) - all todo's allowed late in SDLC" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "suppress( low_priority_todos_for_release ) - low priority allowed late in SDLC" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "template( css|html|js|json|text|wml|xml [, path] ) - script is acting as a template processor" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "test( condition ) - with --test, execute test commands" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "test_result( condition ) - with --test, display warning on condition failure" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "todo( to, message, work, units, priority, units ) - task assignment/estimation" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "unchecked_import( shell | cgi | local_memcache | memcache | session, var ) - import without checking for existence" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "uninspect( var ) - undo pragma inspect" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "unrestricted_template( css|html|js|json|text|wml|xml [, path] ) - don't run template in restricted shell" );
     Put_Line( "  " & bold( "pragma" ) & " " &
       "volatile( var ) - load value from environment on every access" );
end helpPragma;

procedure help( ap : argumentListPtr ) is
  helpTopic : unbounded_string;
  e : aHelpEntry;
  r : aRootReportPtr;
begin
  r := new longHelpReport;
  if ap'length = 0 then
     helpTopic := null_unbounded_string;
  else
     -- TODO: an enum type
     HTMLOutput    := false;
     MANOutput     := false;
     LicenseOutput := false;
     TodoOutput    := false;
     CollabOutput  := false;
     helpTopic := to_unbounded_string( ap( 1 ).all );
     delete( helpTopic, length( helpTopic ), length( helpTopic ) );
     if helpTopic = "-h" then      -- script help (html)
        HTMLOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     elsif helpTopic = "-m" then      -- script help (man page)
        MANOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     elsif helpTopic = "-l" then      -- script licenses
        LicenseOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     elsif helpTopic = "-t" then      -- to-do's
        TodoOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     elsif helpTopic = "-c" then       -- collaboration
        CollabOutput := true;
        if ap'length = 1 then
           helpTopic := null_unbounded_string;
        else
           helpTopic := to_unbounded_string( ap( 2 ).all );
           delete( helpTopic, length( helpTopic ), length( helpTopic ) );
        end if;
     end if;
  end if;

  if length( helpTopic ) = 0 then
     helpMain;
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
     Put_Line( "  to_array( a, s )         to_json( s, a )" );
  elsif helpTopic = "btree_io" then
     helpBTreeIO;
  elsif helpTopic = "calendar" then
     Put_Line( "calendar (package) - time and date operations:" );
     New_Line;
     Put_Line( "  t := clock               y := year( t )           m := month( t )" );
     Put_Line( "  d := day( t )            s := seconds( t )        split( t, y, m, d, s )" );
     Put_Line( "  t := time_of( y,m,d,s )  i := day_of_week( t )    t := to_time( j )" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "case" then
     startHelp( e, "case" );
     summary( e, "case var is...end case" );
     categoryKeyword( e );
     description( e,
        "Test multiple conditions, executing the commands for the condition " &
        "that matches.  If no conditions match, the others case will run." );
     content( e, "case var is when literal|const[|...] => ...when others => ...end case" );
     seeAlsoFlowControl( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "cd" then
     startHelp( e, "cd" );
     summary( e, "cd -|" & ASCII.Quotation & ASCII.Quotation & "|dirname" );
     categoryBuiltin( e );
     description( e,
      "Change the working directory.  Supports AdaScript parameters. " &
      "One parameter is required.  An empty path will change to the user's " &
      "home directory.  A minus sign will revert to the previous directory." );
     params( e, "path - the path to change to (or null string, minus)" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "cgi" then
     Put_Line( "cgi (package) - process CGI commands and cookies:" );
     New_Line;
     Put_Line( "  parsing_errors             input_received             is_index" );
     Put_Line( "  cgi_method                 value( k, i, b )           key_exists( k, i )" );
     Put_Line( "  key_count( k )             argument_count             key( p )" );
     Put_Line( "  key_value_exists( k, v )   put_cgi_header( s )        put_html_head( t, m )" );
     Put_Line( "  put_html_heading( s, p )   put_html_tail              put_error_message( s )" );
     Put_Line( "  my_url                     put_variables              line_count" );
     Put_Line( "  line_count_of_value        line( v )                  value_of_line( k, p )" );
     Put_Line( "  url_decode                 url_encode( s )            html_encode( s )" );
     Put_Line( "  set_cookie( k,v,e,p,d,s )  cookie_value( p )          cookie_count" );
     Put_Line( "  s := key_value( p )" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "chains" then
     Put_Line( "  p := chains.chain_count        e := chains.chain_context " );
     Put_Line( "  b := chains.in_chain" );
  elsif helpTopic = "clear" then
    Put_Line( "clear - reset tty device and clear the screen" );
     startHelp( e, "clear" );
     summary( e, "clear" );
     categoryBuiltin( e );
     description( e,
      "Clear the screen. " &
      "Reset the display device and clear the screen, placing the cursor in " &
      "the top-left corner of the display." );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "close" then
     Put_Line( "close - close an open file" );
     Put_Line( "  close( file )" );
--  elsif helpTopic = "command" then
--     Put_Line( "command - run a Linux command (instead of a built-in command)" );
--     Put_Line( "  " & bold( "command" ) & " cmd" );
  elsif helpTopic = "command_line" then
     Put_Line( "command_line (package) - count and read script arguments" );
     New_Line;
     Put_Line( "  s := argument( p ) - return argument p" );
     Put_Line( "  n := argument_count - number of arguments" );
     Put_Line( "  s := command_name - name used to execute the script");
     Put_Line( "  n := environment.environment_count - number of environment vars" );
     Put_Line( "  s := environment.environment_value( p ) - return environment value p" );
     Put_Line( "  command_line.set_exit_status( n ) - change script exit status code - change script exit status code");
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
     helpDb;
  elsif helpTopic = "db" then
     helpDbm;
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
     Put_Line( "  c := dir_separator             change_dir( p )               remove_dir( p [, r] )" );
     Put_Line( "  p := get_current_dir           s := dir_name( p )            s := base_name( p [, f] )" );
     Put_Line( "  s := file_extension( p )       s := file_name( p )           s := format_pathname( p [,t] )" );
     Put_Line( "  s := expand_path( p [,t] )     make_dir( p )                 close( d )" );
     Put_Line( "  b := is_open( d )              open( d, p )                  read( d, s )" );
  elsif helpTopic = "end_of_file" then
     Put_Line( "end_of_file - true if an in_file file has no more data" );
     Put_Line( "  end_of_file( file )" );
  elsif helpTopic = "end_of_line" then
     Put_Line( "end_of_line - true if an in_file file has reached the end of a line with get" );
     Put_Line( "  end_of_line( file )" );
  elsif helpTopic = "doubly_linked_lists" then
     Put_Line( "doubly_linked_lists - linked lists package" );
     New_Line;
     Put_Line( "append( l, e )                                         s := assemble( l [,d [,f]] )" );
     Put_Line( "assign( l1, l2 )                                       clear( l )" );
     Put_Line( "b := contains( l, e )                                  delete( l, c [,n] )" );
     Put_Line( "delete_first( l [,n] )                                 delete_last( l [,n] )" );
     Put_Line( "disassemble( s, l [,d [,f] ] )                         e := element( c )" );
     Put_Line( "find( l, e, c )                                        first( l, c )" );
     Put_Line( "e := first_element( l )                                flip( l )" );
     Put_Line( "b := has_element( c )" );
     Put_Line( "insert_before( l, c [, n] ) | ( l, c, e [, n] )" );
     Put_Line( "insert_before_and_mark( l, c, c2 [, n] ) | ( l, c, e, c2 [, n] )" );
     Put_Line( "b := is_empty( l )" );
     Put_Line( "e := last_element( l )                                 n := length( l )" );
     Put_Line( "move( l1, l2 )                                         next( c )" );
     Put_Line( "prepend( l, e )                                        previous( c )" );
     Put_Line( "replace_element( l, c, e )                             reverse_elements( l )" );
     Put_Line( "reverse_find( l, e, c )" );
     Put_Line( "splice( l1, c, l2 [,c2] ) | ( l1, c, c2 )" );
     Put_Line( "swap( l, c1, c2 )                                      swap_links( l, c1, c2 )" );
  elsif helpTopic = "dynamic_hash_tables" then
     Put_Line( "dynamic_hash_tables - hash table package" );
     New_Line;
     Put_Line( "add( t, k, v )                  append( t, k, v )" );
     Put_Line( "decrement( t, k [,n] )          v := get( t, k )" );
     Put_Line( "get_first( t, v, f )            get_next( t, v, f )" );
     Put_Line( "b := has_element( t, k )        increment( t, k [,n] )" );
     Put_Line( "prepend( t, k, v )              remove( t, k )" );
     Put_Line( "replace( t, k, v )              reset( t )" );
     Put_Line( "set( t, k, v )" );
  elsif helpTopic = "enums" then
     Put_Line( "enums (package) - enumerated types" );
     New_Line;
     Put_Line( "  enums.first(t)            enums.last(t)            enums.pred(e2)      ");
     Put_Line( "  enums.succ(e2)                                                         ");
  elsif helpTopic = "env" then
     startHelp( e, "env" );
     summary( e, "env [var]" );
     categoryBuiltin( e );
     description( e,
       "Display a list of all declared identifiers, their values and their " &
       "properties, or the properties of a particular identifier.  Supports " &
       "AdaScript parameters." );
     params( e, "var - the identifier to display" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "exceptions" then
     Put_Line( "exceptions - exceptions package functions" );
     New_Line;
     Put_Line( "  s := exceptions.exception_name        s := exceptions.exception_info" );
     Put_Line( "  n := exceptions.exception_status_code" );
  elsif helpTopic = "exit" then
     Put_Line( "exit - break out of a loop" );
     Put_Line( "  " & bold( "exit" ) & " or " &
       bold( "exit" ) & " " & bold("when" ) & " condition" );
  elsif helpTopic = "files" then
     Put_Line( "files - files package functions" );
     New_Line;
     Put_Line( "  b := basename( p )           b := dirname( p )         b := exists( p )" );
     Put_Line( "  b := is_absolute_path( p )   b := is_directory( p )    b := is_executable( p )" );
     Put_Line( "  b := is_executable_file( p ) b := is_regular_file( p ) b := is_readable( p )" );
     Put_Line( "  b := is_readable_file( p )   b := is_waiting_file( p ) b := is_writable( p )  " );
     Put_Line( "  b := is_writable_file( p )   t := last_accessed( p )   t := last_changed( p )" );
     Put_Line( "  t := last_modified( p )      l := size( p )" );
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
     Put_Line( "  " & bold( "function" ) & " f( f1 : mode type [; f2:mode type...]) " & bold( "return" ) & " t " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " f;" );
     New_Line;
     Put_Line( "  " & bold( "function" ) & " f " & bold( "return" ) & " t " & bold( "is separate" ) & ";" );
     Put_Line( "   --load function from include file ""f.bush""" );
     New_Line;
     Put_Line( "Mode may be 'in' or 'in out'" );
  elsif helpTopic = "get" then
     Put_Line( "get - read a character from a line of text" );
     Put_Line( "  get ([file,] ch)" );
  elsif helpTopic = "get_immediate" then
     Put_Line( "get_immediate - read a character from a line of text" );
     Put_Line( "  get_immediate (ch [, b]) - b is true if non-blocking" );
  elsif helpTopic = "get_line" then
     Put_Line( "get_line - read a line of text" );
     Put_Line( "  var := get_line [ (file) ]" );
  elsif helpTopic = "gnat.crc32" then
     Put_Line( "gnat.crc32 (package) - GNAT CRC packages");
     New_Line;
     Put_Line( "  gnat.crc32.initialize( c )" );
     Put_Line( "  gnat.crc32.update(c, s )" );
     Put_Line( "  i := gnat.crc32.get_value( c )" );
  elsif helpTopic = "gnat.cgi" then
     Put_Line( "gnat.cgi (package) - GNAT CGI packages");
     New_Line;
     Put_Line( "  gnat.cgi.put_header [(f) | (h [,f])]" );
     Put_Line( "  b := gnat.cgi.ok" );
     Put_Line( "  m := gnat.cgi.method" );
     Put_Line( "  s := gnat.cgi.metavariable( k [,r] )" );
     Put_Line( "  b := gnat.cgi.metavariable.exists( k )" );
     Put_Line( "  s := gnat.cgi.url" );
     Put_Line( "  n := gnat.cgi.argument_count" );
     Put_Line( "  s := gnat.cgi.value( k [,r] | p )" );
     Put_Line( "  b := gnat.cgi.key_exists( k )" );
     Put_Line( "  s := gnat.cgi.key( p )" );
     Put_Line( "  gnat.cgi.cookie.put_header [ (f) | (h [,f]) ]" );
     Put_Line( "  b := gnat.cgi.cookie_ok" );
     Put_Line( "  n := gnat.cgi.cookie_count" );
     Put_Line( "  s := gnat.cgi.cookie_value( k [,r] )" );
     Put_Line( "  b := gnat.cgi.cookie_exists( k )" );
     Put_Line( "  s := gnat.cgi.cookie_key( p )" );
     Put_Line( "  gnat.cgi.cookie.set( k [,v [,c [,d [,m [,p [,s] ] ] ] ] ] )" );
     Put_Line( "  s := gnat.cgi.debug.text_output" );
     Put_Line( "  s := gnat.cgi.debug.html_output" );
  elsif helpTopic = "help" then
     startHelp( e, "help" );
     summary( e, "help  [-c|-h|-m|-l|-t" );
     categoryBuiltin( e );
     description( e,
      "Show short advice on various topics.  Help can also " &
      "show documentation in a script or run reports. When showing " &
      "script docs, -h will show the annotations in HTML, -m as a man " &
      "page and, with no options, SparForte will show the annotations as " &
      "plain text. With -l, SparForte will show the script license as set " &
      "with pragma license. With -c, the teamwork pragmas will be shown in " &
      "CSV format. With -t, the todo pragmas will be shown in CSV format. " &
      "and with a work summary.  If no topic is known, help will try the " &
      "operating system documentation.  Supports AdaScript parameters.");
     params( e, "-c - show team collaboration report" );
     params( e, "-h - HTML output" );
     params( e, "-l - show script license report" );
     params( e, "-m - UNIX manual page output" );
     params( e, "-t - show todo pragmas and summarize" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "hash_io" then
     helpHashIo;
  elsif helpTopic = "history" then
     startHelp( e, "history" );
     summary( e, "history [amount|-c]" );
     categoryBuiltin( e );
     description( e,
       "show the command history (up to n lines). If the number of lines is " &
       "not specified, show all the command history.  Use -c to erase the " &
       "command history.  Supports AdaScript parameters." );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
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
     startHelp( e, "jobs" );
     summary( e, "jobs" );
     categoryBuiltin( e );
     description( e,
       "Give the status of commands currently running in the background" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "line" then
     Put_Line( "line - the number of read/written lines" );
     Put_Line( "  line( file )" );
  elsif helpTopic = "logout" then
     startHelp( e, "logout" );
     summary( e, "logout" );
     categoryBuiltin( e );
     description( e,
        "Stop an interactive, login session and leave the SparForte shell. " &
        "You have a login session if SparForte is your login shell or " &
        "if you start SparForte with the --login option. When in the " &
        "debugger (breakout mode), logout will abandon the debugger " &
        "session and leave the SparForte shell.  (Use the return command " &
        "to leave a non-login session.)" );
     errors( e, "If the session is not a login session, an error is displayed" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
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
     helpMySQL;
  elsif helpTopic = "mysqlm" then
     helpMySQLM;
  elsif helpTopic = "declare" then
     Put_Line( "declare - begin a new block" );
     Put_Line( "  [" & bold( "declare") & " declarations] " &
       bold( "begin" ) & " ... " & bold( "end" ) );
  elsif helpTopic = "delay" then
     Put_Line( "delay - wait (sleep) for a specific time" );
     Put_Line( "  " & bold( "delay" ) & " secs" );
  elsif helpTopic = "memcache" then
     Put_Line( "memcache - distributed memcache package functions" );
     New_Line;
     Put_Line( "  add( cl, k, v )             prepend( cl, k, v )" );
     Put_Line( "  append( cl, k, v )          register_server( cl, h, p )" );
     Put_Line( "  clear_servers( cl )         replace( cl, k, v )" );
     Put_Line( "  delete( cl, k )             set( cl, k, v )" );
     Put_Line( "  flush( cl )                 set_cluster_name( cl, s )" );
     Put_Line( "  is_valid_memcache_key( k )  set_cluster_type( cl, e )" );
     Put_Line( "  v := get( cl, k )           s := stats( cl )" );
     Put_Line( "  cl := new_cluster           s := version( cl )" );
     New_Line;
     Put_Line( "memcache.highread - distributed dual memcache package functions" );
     New_Line;
     Put_Line( "  add( cl, k, v )             register_alpha_server( cl, h, p )" );
     Put_Line( "  append( cl, k, v )          register_beta_server( cl, h, p )" );
     Put_Line( "  clear_servers( cl )         replace( cl, k, v )" );
     Put_Line( "  delete( cl, k )             set( cl, k, v )" );
     Put_Line( "  flush( cl )                 set_cluster_name( cl, s )" );
     Put_Line( "  v := get( cl, k )           set_cluster_type( cl, e )" );
     Put_Line( "  cl := new_cluster           s := stats( cl )" );
     Put_Line( "  prepend( cl, k, v )         s := version( cl )" );
  elsif helpTopic = "mode" then
     Put_Line( "mode - the file mode (in_file, out_file, append_file)" );
     Put_Line( "  mode( file )" );
  elsif helpTopic = "name" then
     Put_Line( "name - name of an open file" );
     Put_Line( "  name( file )" );
  elsif helpTopic = "null" then
     Put_Line( "null - do nothing" );
  elsif helpTopic = "os" then
     Put_Line( "os - SparForte operating system binding" );
     Put_Line( "  i := status" );
     Put_Line( "  s := strerror( i )" );
     Put_Line( "  system( s )" );
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
     Put_Line( "  " & bold( "procedure" ) & " p( f1 : mode type [; f2:mode type...]) " & bold( "is" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "begin" ) );
     Put_Line( "  ..." );
     Put_Line( "  " & bold( "end" ) & " p;" );
     New_Line;
     Put_Line( "Mode may be 'in', 'out' or 'in out'" );
  elsif helpTopic = "pragma" then
     helpPragma;
  elsif helpTopic = "put" then
     Put_Line( "put - write to output, no new line" );
     Put_Line( "  put ( [file], expression [,picture] )" );
  elsif helpTopic = "put_line" then
     Put_Line( "put_line - write to output and start new line" );
     Put_Line( "  put_line ( [file], expression )" );
  elsif helpTopic = "pwd" then
     startHelp( e, "pwd" );
     summary( e, "pwd" );
     categoryBuiltin( e );
     description( e,
        "Show the path of the present (current) working directory " );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "records" then
     Put_Line( "records - records package functions" );
     New_Line;
     Put_Line( "  to_record( r, s )        to_json( s, r )" );
     New_Line;
  elsif helpTopic = "raise" then
     Put_Line( "raise [e [with s] ] - raise (throw) an exception" );
     New_Line;
     Put_Line( "  raise   - re-raise an exception in an exception handler" );
     Put_Line( "  raise e - raise exception e" );
     Put_Line( "  raise e with s - raise exception e with new message s" );
     New_Line;
  elsif helpTopic = "reset" then
     Put_Line( "reset - reopen a file" );
     Put_Line( "  reset( file [,mode])" );
  elsif helpTopic = "return" then
     Put_Line( "return - exit script and return status code" );
     Put_Line( "  " & bold( "return") );
  elsif helpTopic = "typeset" then
     startHelp( e, "typeset" );
     summary( e, "typeset var is type" );
     categoryBuiltin( e );
     description( e,
        "Change the type of a variable, declaring it if necssary. It will " &
        "attempt to typecast the value of the variable if the variable " &
        "exists." );
     errors( e, "An exception is raised if the variable cannot be typecast" );
     errors( e, "An exception is raised if pragma ada_95 is enforced" );
     errors( e, "An exception is raised if not used in an interactive session" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
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
     Put_Line( "  s := enclosing_entity - name of script (if a procedure block)" );
     Put_Line( "  s := file - file name without a path" );
     Put_Line( "  p := line - current line number" );
     Put_Line( "  n := script_size - size of compiled script (bytes)" );
     Put_Line( "  s := source_location - file and line number" );
     Put_Line( "  n := symbol_table_size - number of identifiers" );
     New_Line;
     discardUnusedIdentifier( token );
  elsif helpTopic = "stats" then
     Put_Line( "stats - stats package functions" );
     New_Line;
     Put_Line("  r := average( a )             r := max( a )              r := min( a )" );
     Put_Line("  r := standard_deviation( a )  r := sum( a )              r := variance( a )" );
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
     Put_Line( "  System.Restricted_Shell       System.Script_License" );
     Put_Line( "  System.Script_Software_Model  System.System_Version" );
     discardUnusedIdentifier( token );
  elsif helpTopic = "teams" then
     Put_Line( "teams - the development team package" );
     New_Line;
     Put_Line( "  teams.member - a team member" );
     Put_Line( "  teams.work_measure - the measure of work effort" );
     Put_Line( "  teams.work_priority - the measure of work priority" );
  elsif helpTopic = "templates" then
     Put_Line( "templates - the templates package" );
     New_Line;
     Put_Line( "  b := has_put_template_header" );
     Put_Line( "  put_template_header" );
     Put_Line( "  set_http_location( n )" );
     Put_Line( "  set_http_status( i )" );
  elsif helpTopic = "trace" then
     startHelp( e, "trace" );
     summary( e, "trace [true|false]" );
     categoryBuiltin( e );
     description( e,
        "Show which lines are read as the script runs. The lines are " &
        "displayed, along with additional information in parentheses, " &
        "showing how SparForte interprets the commands. The line number " &
        "is displayed in square brackets after the line. trace by " &
        "itself gives the current trace status (true or false).  false " &
        "turns off tracing.  Supports AdaScript parameters." );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
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
     helpUnits;
  elsif helpTopic = "unset" then
     startHelp( e, "unset" );
     summary( e, "unset ident" );
     categoryBuiltin( e );
     description( e,
         "Delete a variable, data type or other identifier.  Keywords " &
         "cannot be unset.  Supports AdaScript parameters." );
     errors( e, "An exception is raised if pragma ada_95 is enforced" );
     errors( e, "An exception is raised if not used in an interactive session" );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
  elsif helpTopic = "wait" then
      startHelp( e, "wait" );
     summary( e, "wait" );
     categoryBuiltin( e );
     description( e,
        "Stop execution and wait for all background commands to finish and " &
        "return the exit status of the last command." );
     seeAlsoShellCmds( e );
     endHelp( e );
     start( r.all );
     render( longHelpReport( r.all ), e ); -- TODO: fix typecast
     finish( r.all );
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
     helpNumerics;
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
     Put_Line( "  paint_ellipse( id, r )                                                      ");
     Put_Line( "  line_to( id, x, y )       line( id, dx, dy )       hline( id, x1, x2, y )   ");
     Put_Line( "  vline( id, x, y1, y2 )    move_to( id, x, y )      move( id, dx, dy )       ");
     Put_Line( "  clear                     clear( r, g, b)          clear( cn )              ");
     New_Line;
     Put_Line( "  get_pen_mode( id )        get_pen_brush( id )      set_pen_ink(id,r,g,b)    " );
     Put_Line( "  set_pen_ink(id,cn)        set_pen_mode( id, m)     set_pen_pattern( id,pid) " );
     Put_Line( "  set_pen_brush( id,brush ) set_font( c, f, p )*     put( c, s )*             ");
     Put_Line( "  p := greyscale( r,g,b) blend(r1,g1,b1,r2,g2,b2,r,g,b) fade(r1,g1,b1,p,r,g,b)");
     New_Line;
     Put_Line( "  new_canvas(h,v,c,id) new_screen_canvas(h,v,c,id) new_window_canvas(h,v,c,id)");
     Put_Line( "  new_canvas(p,id)     new_gl_screen_canvas(h,v,c,id)  save_canvas(p,id)      ");
     Put_Line( "  close_canvas( id )   new_gl_window_canvas(h,v,c,id)  wait_to_reveal( id )" );
     Put_Line( "reveal( id )           reveal_now( id )                                                            ");
  elsif helpTopic = "step" then
     Put_Line( "step - on --break breakout, run one instruction and stop" );
     Put_Line( "  " & bold( "step" ) );
  elsif helpTopic = "strings" then
     Put_Line( "strings - strings package functions" );
     New_Line;
     Put_Line("  n := count( s, p )             r := csv_field( s, c [, d] )  r := csv_replace( s, f, t, [, d] )" );
     Put_Line("  r := delete( s, l, h )         c := element( s, p )          r := field( s, c [, d] )" );
     Put_Line("  b := glob( e, s )              r := head( s, c [, p] )" );
     Put_Line("  r := strings.image( n )        n := index( s, p [, d] )      n := index_non_blank( s [,d] )" );
     Put_Line("  r := insert( s, b, n )         r := is_alphanumeric( s )     r := is_basic( s )" );
     Put_Line("  r := is_control( s )           r := is_digit( s )            r := is_fixed( s )" );
     Put_Line("  r := is_graphic( s )           r := is_hexadecimal_digit(s)  r := is_letter( s )" );
     Put_Line("  r := is_lower( s )             r := is_slashed_date( s )     r := is_special( s )" );
     Put_Line("  b := is_typo_of( s1, s2 )      r := is_upper( s )            n := length( s )" );
     Put_Line("  r := lookup( s, k [, d] )      b := match( e, s )            r := mktemp( p )" );
     Put_Line("  r := overwrite( s, p, n )      replace( s, f, t [, d] )      replace_slice( s, l, h, b )" );
     Put_Line("  set_unbounded_string( u, s )   r := slice( s, l, h )         split( s, l, r , p )" );
     Put_Line("  r := tail( s, c [, p] )        r := strings.to_base64( s )   r := to_basic( s )" );
     Put_Line("  r := to_escaped( s )           r := to_json( s )             r := to_lower( s )" );
     Put_Line("  r := to_proper( s )            r := to_string( s )           r := to_upper( s )" );
     Put_Line("  u := to_unbounded_string( s )  r := trim( s [, e] )          r := unbounded_slice(s, l, h)" );
     Put_Line("  c := val( n ) " );
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
     DoScriptHelp( helpTopic );
  end if;
  free( r );
-- getNextToken;
end help;

end builtins.help;

