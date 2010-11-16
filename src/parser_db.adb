------------------------------------------------------------------------------
-- BUSH Database Package Parser                                             --
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
-- CVS: $Id: parser_db.adb,v 1.3 2005/08/17 23:46:30 ken Exp $

with text_io;use text_io;
with ada.io_exceptions,
     ada.strings.unbounded,
     APQ.PostgreSQL.Client,
     bush_os.tty,
     world,
     signal_flags,
     string_util,
     user_io,
     scanner,
     parser,
     parser_aux;
use  ada.io_exceptions,
     ada.strings.unbounded,
     APQ,
     APQ.PostgreSQL,
     APQ.PostgreSQL.Client,
     bush_os.tty,
     world,
     signal_flags,
     string_util,
     user_io,
     scanner,
     parser,
     parser_aux;

package body parser_db is

Q : Query_Type;
C : Connection_Type;
-- for the time being, a single query

procedure ParseDBConnect is
  -- Syntax: db.connect( dbname [,user ,passwd [,host [,port ] ] ] );
  dbnameExpr : unbounded_string;
  dbnameType : identifier;
  userExpr : unbounded_string;
  userType : identifier;
  hasUser  : boolean := false;
  pswdExpr : unbounded_string;
  pswdType : identifier;
  hostExpr : unbounded_string;
  hostType : identifier;
  hasHost  : boolean := false;
  portExpr : unbounded_string;
  portType : identifier;
  hasPort  : boolean := false;
begin
  -- temporary limitation: only one database open at a time...
  expect( db_connect_t );
  if engineOpen then
     err( "only one database connection may be open (a limitation of this verison of bush)" );
     return;
  end if;
  expect( symbol_t, "(" );
  ParseExpression( dbnameExpr, dbnameType );
  if baseTypesOK( string_t, dbnameType ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        ParseExpression( userExpr, userType );
        if baseTypesOK( string_t, userType ) then
           hasUser := true;
           expect( symbol_t, "," );
           ParseExpression( pswdExpr, pswdType );
           if baseTypesOK( string_t, pswdType ) then
              if token = symbol_t and identifiers( token ).value = "," then
                 expect( symbol_t, "," );
                 ParseExpression( hostExpr, hostType );
                 if baseTypesOK( string_t, hostType ) then
                    hasHost := true;
                    if token = symbol_t and identifiers( token ).value = "," then
                       expect( symbol_t, "," );
                       ParseExpression( portExpr, portType );
                       if baseTypesOK( integer_t, portType ) then
                          hasPort := true;
                       end if;
                    end if;
                 end if;
              end if;
           end if;
        end if;
     end if;
  end if;
  expect( symbol_t, ")" );
  if isExecutingCommand then
     begin
       begin
         Set_DB_Name( C, to_string( dbnameExpr ) );
       exception when others =>
         err( to_string( "Internal error: set_db_name " & dbnameExpr &
              " failed" ) );
       end;
       if hasUser then
          begin
            Set_User_Password( C, to_string( userExpr ), to_string( pswdExpr ) );
          exception when others =>
             err( to_string( "Internal error: set_user_password " & userExpr &
                  "/" & pswdExpr & " failed" ) );
          end;
       end if;
       if hasHost then
          begin
             Set_Host_Name( C, to_string( hostExpr ) );
          exception when others =>
             err( to_string( "Internal error: set_host_name " & hostExpr &
                  " failed" ) );
          end;
       end if;
       if hasPort then
          begin
            Set_Port( C, integer( to_numeric( portExpr ) ) );
          exception when others =>
             err( to_string( "Internal error: set_port " & portExpr &
                  " failed" ) );
          end;
       end if;
       Connect( C );
       engineOpen := true;
       currentEngine := Engine_PostgreSQL;
     exception when not_connected =>
        if hasHost and hasPort then
           err( "database connection failed - User " & User( C ) & ", Password " & Password( C )
           & ", Host " & Host_Name( C ) & "and Port " & integer'image( Port( C ) ) & " " & DB_Name( C ) );
        else
          err( "database connection failed" );
        end if;
     when already_connected =>
        err( "already connected to database" );
     when others =>
        err( "exception raised" );
     end;
  end if;
end ParseDBConnect;

procedure ParseDBEngineOf( result : out unbounded_string ) is
  -- Syntax: b := db.engine_of;
  -- Source: APQ.Engine_Of
begin
  expect( db_engine_of_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( integer'image( Database_Type'pos( Engine_Of( C ) ) ) );
       if length( result ) > 0 then
          if element( result, 1 ) = ' ' then
             delete( result, 1, 1 );
          end if;
       end if;
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBEngineOf;

procedure ParseDBIPrepare( result : out unbounded_string ) is
  -- Syntax: db.prepare( sqlstmt [,after] );
  sqlExpr   : unbounded_string;
  sqlType   : identifier;
  afterExpr : unbounded_string;
  afterType : identifier;
  hasAfter  : boolean := false;
begin
  expect( db_prepare_t );
  expect( symbol_t, "(" );
  ParseExpression( sqlExpr, sqlType );
  if baseTypesOK( string_t, sqlType ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        ParseExpression( afterExpr, afterType );
        if baseTypesOK( string_t, sqlType ) then
           hasAfter := true;
        end if;
     end if;
  end if;
  expect( symbol_t, ")" );
  if isExecutingCommand then  
     result := to_bush_boolean( true );
     begin
       Clear( Q );
       if hasAfter then
          Prepare( Q, to_string( sqlExpr ), to_string( afterExpr ) );
       else
          Prepare( Q, to_string( sqlExpr ) );
       end if;
     exception when others =>
       result := to_bush_boolean( false );
     end;
  end if;
end ParseDBIPrepare;

procedure ParseDBPrepare is
  -- Syntax: db.prepare( sqlstmt [,after] );
  sqlExpr   : unbounded_string;
  sqlType   : identifier;
  afterExpr : unbounded_string;
  afterType : identifier;
  hasAfter  : boolean := false;
begin
  expect( db_prepare_t );
  expect( symbol_t, "(" );
  ParseExpression( sqlExpr, sqlType );
  if baseTypesOK( string_t, sqlType ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        ParseExpression( afterExpr, afterType );
        if baseTypesOK( string_t, afterType ) then
           hasAfter := true;
        end if;
     end if;
  end if;
  expect( symbol_t, ")" );
  if isExecutingCommand then  
     begin
       if hasAfter then
          Prepare( Q, to_string( sqlExpr ), to_string( afterExpr ) );
       else
          Prepare( Q, to_string( sqlExpr ) );
       end if;
     exception when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBPrepare;

procedure ParseDBAppend is
  -- Syntax: db.append( sqlstmt [,after] );
  sqlExpr   : unbounded_string;
  sqlType   : identifier;
  afterExpr : unbounded_string;
  afterType : identifier;
  hasAfter  : boolean := false;
begin
  expect( db_append_t );
  expect( symbol_t, "(" );
  ParseExpression( sqlExpr, sqlType );
  if baseTypesOK( string_t, sqlType ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        ParseExpression( afterExpr, afterType );
        if baseTypesOK( string_t, afterType ) then
           hasAfter := true;
        end if;
     end if;
  end if;
  expect( symbol_t, ")" );
  if isExecutingCommand then  
     begin
       if hasAfter then
          Append( Q, to_string( sqlExpr ), to_string( afterExpr ) );
       else
          Append( Q, to_string( sqlExpr ) );
       end if;
     exception when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBAppend;

procedure ParseDBAppendLine is
  -- Syntax: db.append_line( sqlstmt );
  sqlExpr   : unbounded_string;
  sqlType   : identifier;
begin
  expect( db_append_line_t );
  expect( symbol_t, "(" );
  ParseExpression( sqlExpr, sqlType );
  if baseTypesOK( string_t, sqlType ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then  
     begin
       Append_Line( Q, to_string( sqlExpr ) );
     exception when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBAppendLine;

procedure ParseDBAppendQuoted is
  -- Syntax: db.append_quoted( sqlstmt [,after] );
  sqlExpr   : unbounded_string;
  sqlType   : identifier;
  afterExpr : unbounded_string;
  afterType : identifier;
  hasAfter  : boolean := false;
begin
  expect( db_append_quoted_t );
  expect( symbol_t, "(" );
  ParseExpression( sqlExpr, sqlType );
  if baseTypesOK( sqlType, string_t ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        hasAfter := true;
        ParseExpression( afterExpr, afterType );
        if baseTypesOK( afterType, string_t ) then
           null;
        end if;
     end if;
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then  
     begin
       if hasAfter then
          Append_Quoted( Q, C, to_string( sqlExpr ), to_string( afterExpr ) );
       else
          Append_Quoted( Q, C, to_string( sqlExpr ) );
       end if;
     exception when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBAppendQuoted;

procedure ParseDBExecute is
begin
  expect( db_execute_t );
  if isExecutingCommand then
     begin
       Execute( Q, C );
     exception when not_connected =>
       err( "not connected" );
     when abort_state =>
       err( "in abort state" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBExecute;

procedure ParseDBExecuteChecked is
  -- Syntax: db.execute_checked( [ msg ] );
  msgExpr   : unbounded_string;
  msgType   : identifier;
  hasMsg    : boolean := false;
begin
  expect( db_execute_checked_t );
  if token = symbol_t and identifiers( token ).value = "(" then
     expect( symbol_t, "(" );
     ParseExpression( msgExpr, msgType );
     if baseTypesOK( string_t, msgType ) then
        expect( symbol_t, ")" );
     end if;
     hasMsg := true;
  end if;
  if isExecutingCommand then
     begin
       if hasMsg then
          Execute_Checked( Q, C, to_string( msgExpr ) );
       else
          Execute_Checked( Q, C );
       end if;
     exception when not_connected =>
       err( "not connected" );
     when abort_state =>
       err( "in abort state" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception raised" );
     end;
  end if;
end ParseDBExecuteChecked;

--procedure ParseDBDo( result : out unbounded_string ) is
--begin
--  expect( db_do_t );
--  result := null_unbounded_string;
--end ParseDBDo;
--
--procedure ParseDBFetchrow( result : out unbounded_string ) is
--begin
--  expect( db_fetchrow_t );
--  result := null_unbounded_string;
--end ParseDBFetchrow;

procedure ParseDBDisconnect is
  -- Syntax: db.disconnect;
begin
  expect( db_disconnect_t );
  if isExecutingCommand then
     begin
        Disconnect( C );
        engineOpen := false;
     exception when not_connected =>
        err( "no database connection" );
     when already_connected =>
        err( "already connected to database" );
     when others =>
        err( "exception raised" );
     end;
  end if;
end ParseDBDisconnect;

procedure ParseDBIsConnected( result : out unbounded_string ) is
  -- Syntax: db.is_connected
begin
  expect( db_is_connected_t );
  if isExecutingCommand then
     begin
       result := to_bush_boolean( is_connected( C ) ); 
     exception when others =>
       result := to_bush_boolean( false );
     end;
  end if;
end ParseDBIsConnected;

procedure ParseDBReset is
  -- Syntax: db.reset
  -- Source: APQ.Reset
begin
  expect( db_reset_t );
  if isExecutingCommand then
     begin
       Reset( C );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBReset;

procedure ParseDBErrorMessage( result : out unbounded_string ) is
  -- Syntax: db.error_message
  -- Source: APQ.Error_Message
begin
  expect( db_error_message_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Error_Message( C ) );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBErrorMessage;

procedure ParseDBNoticeMessage( result : out unbounded_string ) is
  -- Syntax: db.notice_message
  -- Source: APQ.Notice_Message
begin
  expect( db_notice_message_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Notice_Message( C ) );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBNoticeMessage;

procedure ParseDBInAbortState( result : out unbounded_string ) is
  -- Syntax: db.in_abort_state
  -- Source: APQ.In_Abort_State
begin
  expect( db_in_abort_state_t );
  if isExecutingCommand then
     begin
       result := to_bush_boolean( In_Abort_State( C ) );
     exception when not_connected =>
       err( "not connected" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBInAbortState;

procedure ParseDBOptions( result : out unbounded_string ) is
  -- Syntax: db.options
  -- Source: APQ.Options
begin
  expect( db_options_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Options( C ) );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBOptions;

procedure ParseDBSetRollbackOnFinalize is
  -- Syntax: db.set_rollback_on_finalize( b );
  -- Source: APQ.Set_Rollback_On_Finalize
  rollExpr : unbounded_string;
  rollType : identifier;
begin
  expect( db_set_rollback_on_finalize_t );
  expect( symbol_t, "(" );
  ParseExpression( rollExpr, rollType );
  if baseTypesOK( rollType, boolean_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     declare
       rollback : boolean := rollExpr = to_unbounded_string( "1" );
     begin
       Set_Rollback_On_Finalize( C, rollback );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBSetRollbackOnFinalize;

procedure ParseDBWillRollbackOnFinalize( result : out unbounded_string ) is
  -- Syntax: db.will_rollback_on_finalize( b );
  -- Source: APQ.Will_Rollback_On_Finalize
begin
  expect( db_will_rollback_on_finalize_t );
  begin
    result := to_bush_boolean( Will_Rollback_On_Finalize( C ) );
  exception when others =>
    err( "exception was raised" );
  end;
end ParseDBWillRollbackOnFinalize;

procedure ParseDBOpenDBTrace is
  -- Syntax: db.open_db_trace( f [,m] );
  -- Source: APQ.Open_DB_Trace
  fnameExpr : unbounded_string;
  fnameType : identifier;
  modeExpr  : unbounded_string;
  modeType  : identifier;
  traceMode : trace_mode_type;
  hasMode  : boolean := false;
begin
  expect( db_open_db_trace_t );
  expect( symbol_t, "(" );
  ParseExpression( fnameExpr, fnameType );
  if baseTypesOK( fnameType, string_t ) then
     if token = symbol_t and identifiers( token ).value = "," then
        expect( symbol_t, "," );
        ParseExpression( modeExpr, modeType );
        if baseTypesOK( modeType, db_trace_mode_type_t ) then
           traceMode := Trace_Mode_Type'val( integer'value( ' ' & to_string( modeExpr ) ) );
           hasMode := true;
        end if;
     end if;
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
       if hasMode then
          Open_DB_Trace( C, to_string( fnameExpr ), traceMode );
       else
          Open_DB_Trace( C, to_string( fnameExpr ) );
       end if;
     exception when not_connected =>
       err( "not connected" );
     when tracing_state =>
       err( "file already open" );
     when Ada.IO_Exceptions.Name_Error =>
       err( "file not found" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBOpenDBTrace;

procedure ParseDBCloseDBTrace is
  -- Syntax: db.close_db_trace( f );
  -- Source: APQ.Close_DB_Trace
begin
  expect( db_close_db_trace_t );
  if isExecutingCommand then
     begin
       Close_DB_Trace( C );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBCloseDBTrace;

procedure ParseDBSetTrace is
  -- Syntax: db.set_trace( b );
  -- Source: APQ.Set_Trace
  traceExpr : unbounded_string;
  traceType : identifier;
begin
  expect( db_set_trace_t );
  expect( symbol_t, "(" );
  ParseExpression( traceExpr, traceType );
  if baseTypesOK( traceType, boolean_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     declare
       traceback : boolean := traceExpr = to_unbounded_string( "1" );
     begin
       Set_Trace( C, traceback );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBSetTrace;

procedure ParseDBIsTrace( result : out unbounded_string ) is
  -- Syntax: db.is_trace( b );
  -- Source: APQ.Is_Trace
begin
  expect( db_is_trace_t );
  begin
    result := to_bush_boolean( Is_Trace( C ) );
  exception when others =>
    err( "exception was raised" );
  end;
end ParseDBIsTrace;

procedure ParseDBClear is
  -- Syntax: db.clear;
  -- Source: APQ.Clear
begin
  expect( db_clear_t );
  begin
    Clear( Q );
  exception when others =>
    err( "exception was raised" );
  end;
end ParseDBClear;

procedure ParseDBRaiseExceptions is
  -- Syntax: db.raise_exceptions( [ b ] );
  -- Source: APQ.Raise_Exceptions
  raiseExpr : unbounded_string;
  raiseType : identifier;
begin
  expect( db_raise_exceptions_t );
  if token = symbol_t and identifiers( token ).value = "(" then
     expect( symbol_t, "(" );
     ParseExpression( raiseExpr, raiseType );
     if baseTypesOK( raiseType, boolean_t ) then
        expect( symbol_t, ")" );
     end if;
  else
     raiseExpr := to_unbounded_string( "1" );
  end if;
  if isExecutingCommand then
     declare
       raise_them : boolean := raiseExpr = to_unbounded_string( "1" );
     begin
       Raise_Exceptions( Q, raise_them );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBRaiseExceptions;

procedure ParseDBReportErrors is
  -- Syntax: db.report_errors( [ b ] );
  -- Source: APQ.Report_Errors
  reportExpr : unbounded_string;
  reportType : identifier;
begin
  expect( db_report_errors_t );
  if token = symbol_t and identifiers( token ).value = "(" then
     expect( symbol_t, "(" );
     ParseExpression( reportExpr, reportType );
     if baseTypesOK( reportType, boolean_t ) then
        expect( symbol_t, ")" );
     end if;
  else
     reportExpr := to_unbounded_string( "1" );
  end if;
  if isExecutingCommand then
     declare
       report_them : boolean := reportExpr = to_unbounded_string( "1" );
     begin
       Report_Errors( Q, report_them );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBReportErrors;

procedure ParseDBBeginWork is
  -- Syntax: db.begin_work;
  -- Source: APQ.Begin_Work
begin
  expect( db_begin_work_t );
  if isExecutingCommand then
     begin
       Begin_Work( Q, C );
     exception when abort_state =>
       err( "in abort state" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBBeginWork;

procedure ParseDBRollbackWork is
  -- Syntax: db.rollback_work;
  -- Source: APQ.Rollback_Work
begin
  expect( db_rollback_work_t );
  if isExecutingCommand then
     begin
       Rollback_Work( Q, C );
     exception when abort_state =>
       err( "in abort state" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBRollbackWork;

procedure ParseDBCommitWork is
  -- Syntax: db.commit_work;
  -- Source: APQ.Commit_Work
begin
  expect( db_commit_work_t );
  if isExecutingCommand then
     begin
       Commit_Work( Q, C );
     exception when abort_state =>
       err( "in abort state" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBCommitWork;

procedure ParseDBRewind is
  -- Syntax: db.rewind;
  -- Source: APQ.Rewind
begin
  expect( db_rewind_t );
  if isExecutingCommand then
     begin
       Rewind( Q );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBRewind;

procedure ParseDBFetch is
  -- Syntax: db.fetch;
  -- Source: APQ.Fetch
  expr_val : unbounded_string;
  expr_type : identifier;
  haveIndex : boolean := false;
begin
  expect( db_fetch_t );
  if token = symbol_t and identifiers( token ).value = "(" then
     expect( symbol_t, "(" );
     parseExpression( expr_val, expr_type );
     if baseTypesOK( expr_type, db_tuple_index_type_t ) then
        expect( symbol_t, ")" );
        haveIndex := true;
     end if;
  end if;
  if isExecutingCommand then
     begin
       if haveIndex then
          Fetch( Q, Tuple_Index_Type( to_numeric( expr_val ) ) );
       else
          Fetch( Q );
       end if;
     exception when no_tuple =>
       err( "no tuple" );
     when no_result =>
       err( "no result" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBFetch;

procedure ParseDBEndOfQuery( result : out unbounded_string ) is
  -- Syntax: b := db.end_of_query;
  -- Source: APQ.End_Of_Query
begin
  expect( db_end_of_query_t );
  if isExecutingCommand then
     begin
       result := to_bush_boolean( End_Of_Query( Q ) );
     exception when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBEndOfQuery;

procedure ParseDBTuple( result : out unbounded_string ) is
  -- Syntax: t := db.tuple;
  -- Source: APQ.Tuple
begin
  expect( db_tuple_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Tuple_Index_Type'image( Tuple( Q ) ) );
     exception when no_tuple =>
       err( "no tuple" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBTuple;

procedure ParseDBTuples( result : out unbounded_string ) is
  -- Syntax: n := db.tuples;
  -- Source: APQ.Tuples
begin
  expect( db_tuples_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Tuple_Count_Type'image( Tuples( Q ) ) );
     exception when no_result =>
       err( "no result" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBTuples;

procedure ParseDBColumns( result : out unbounded_string ) is
  -- Syntax: n := db.columns;
  -- Source: APQ.Columns
begin
  expect( db_columns_t );
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Natural'image( Columns( Q ) ) );
     exception when no_result =>
       err( "no result" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBColumns;

procedure ParseDBColumnName( result : out unbounded_string ) is
  -- Syntax: n := db.column_Name;
  -- Source: APQ.Column_Name;
  exprVal : unbounded_string;
  exprType : identifier;
begin
  expect( db_column_name_t );
  expect( symbol_t, "(" );
  ParseExpression( exprVal, exprType );
  if baseTypesOK( exprType, db_column_index_type_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
       result := to_unbounded_string(
          Column_Name( Q, Column_Index_Type( to_numeric( exprVal ) ) )
       );
     exception when no_column =>
       err( "no column" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBColumnName;

procedure ParseDBColumnIndex( result : out unbounded_string ) is
  -- Syntax: n := db.column_index;
  -- Source: APQ.Column_Index
  exprVal : unbounded_string;
  exprType : identifier;
begin
  expect( db_column_index_t );
  expect( symbol_t, "(" );
  ParseExpression( exprVal, exprType );
  if baseTypesOK( exprType, string_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
       result := to_unbounded_string( Column_Index_Type'image(
           Column_Index( Q, to_string( exprVal ) )
       ) );
     exception when no_column =>
       err( "no column" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBColumnIndex;

--procedure ParseDBColumnType( result : out unbounded_string ) is
  -- Syntax: n := db.column_type;
  -- Source: APQ.Column_Type;
  --exprVal : unbounded_string;
  --exprType : identifier;
--begin
  --expect( db_column_type_t );
  --expect( symbol_t, "(" );
  --ParseExpression( exprVal, exprType );
  --if baseTypesOK( exprType, db_column_index_type_t ) then
     --expect( symbol_t, ")" );
  --end if;
  --if isExecutingCommand then
     --begin
       --result := to_unbounded_string(
          --Column_Type( Q,
          --Column_Index_Type( to_numeric( exprVal ) ) )
       --);
     --exception when no_column =>
       --err( "no column" );
     --when no_result =>
       --err( "no result" );
     --when others =>
       --err( "exception was raised" );
     --end;
  --end if;
--end ParseDBColumnType;

procedure ParseDBIsNull( result : out unbounded_string ) is
  -- Syntax: n := db.is_null;
  -- Source: APQ.Is_Null;
  exprVal : unbounded_string;
  exprType : identifier;
begin
  expect( db_is_null_t );
  expect( symbol_t, "(" );
  ParseExpression( exprVal, exprType );
  if baseTypesOK( exprType, db_column_index_type_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
       result := to_bush_boolean(
          Is_Null( Q,
          Column_Index_Type( to_numeric( exprVal ) ) )
       );
     exception when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBIsNull;

procedure ParseDBValue( result : out unbounded_string ) is
  -- Syntax: n := db.value;
  -- Source: APQ.Value;
  exprVal  : unbounded_string;
  exprType : identifier;
begin
  expect( db_value_t );
  expect( symbol_t, "(" );
  ParseExpression( exprVal, exprType );
  if baseTypesOK( exprType, db_column_index_type_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
       result := Value( Q, Column_Index_Type( to_numeric( exprVal ) ) );
     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBValue;

procedure DBShowIt is
-- run SQL command and display results in tabular format
  tabularDisplay : boolean := false;
  headingWidth   : integer := 0;
  wasNull        : boolean := false;
  columnWidths   : array( 1..32 ) of integer;
  totalWidth     : integer;
  width          : integer;
begin
  if isExecutingCommand then
     begin
     if is_connected( C ) then
        execute( Q, C );

        -- Initially, the columns widths are the widths of the headings

        for i in 1..columns( Q ) loop
            columnWidths( i ) := column_name( Q, Column_Index_Type( i ) )'length;
            if columnWidths( i ) < 4 then -- room for NULL on tabular display
               columnWidths( i ) := 4;
            end if;
            if headingWidth < columnWidths( i ) then
               headingWidth := columnWidths( i );
            end if;
        end loop;

        -- Check query results and adjust the columns widths for the longest
        -- results.

        while not end_of_query( Q ) loop
              fetch( Q );
              for i in 1..columns( Q ) loop
                 if not is_null( Q, Column_Index_Type( i ) ) then
                    width := length( to_unbounded_string( Value( Q, Column_Index_Type( i ) ) ) );
                    if width > 256 then
                       width := 256;
                    end if;
                    if width > columnWidths( i ) then
                       columnWidths( i ) := width;
                    end if;
                 end if;
              end loop;
        end loop;

        -- Add up all columns for the total width for a tabular display

        totalWidth := 2;                                        -- left/right marg
        for i in 1..columns( Q ) loop
            totalWidth := totalWidth + columnWidths( i );       -- width of column
            if i /= columns(Q) then                             -- not last col?
               totalWidth := totalWidth + 3;                    -- 3 char sep
            end if;
        end loop;

        -- Rewind the clear and prepare to show the results

        Rewind( Q );
        new_line;

        -- Use a tabular display only if will fit in the current display

        tabularDisplay := totalWidth <= integer( displayInfo.col );

        -- Draw the columns

        if tabularDisplay then
           put( " " );
           for i in 1..columns( Q ) loop
               put(
                  to_string(
                      Head(
                          to_unbounded_string(
                              column_name( Q, Column_Index_Type( i ) ) )
                      , columnWidths( i ) )
                  )
               );
               if i /= columns( Q ) then
                  put( " | " );
               end if;
           end loop;
           new_line;
           put( "-" );
           for i in 1..columns( Q ) loop
               put( to_string( columnWidths( i ) * "-" ) );
               if i /= columns( Q ) then
                  put( "-+-" );
               else
                  put( "-" );
               end if;
           end loop;
           new_line;
        end if;

        -- Draw the query results

        while not end_of_query( Q ) loop
            fetch( Q );
            if tabularDisplay then
               put( " " );
            end if;
            for i in 1..columns( Q ) loop
                if tabularDisplay then
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( to_string( Head( to_unbounded_string( "NULL" ), columnWidths( i ) ) ) ) );
                      wasNull := true;
                   else
                      put( to_string( Head( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                   end if;
                   if i /= columns( Q ) then
                      put( " | " );
                   end if;
                else
                   put( to_string( head( to_unbounded_string( column_name( Q, Column_Index_Type( i ) ) ), headingWidth ) ) );
                   put( ": " );
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( "NULL" ) );
                      wasNull := true;
                   else
                      put( bold( to_string( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) );
                   end if;
                   new_line;
                end if;
                exit when wasSIGINT;
            end loop;
            new_line;
        end loop;
     end if;

     -- Draw the summary line

     if tuples( Q ) > 1 and columns ( Q ) > 1 then
        if tuples( Q ) = 1 then
           put( " 1 Row" );
        else
           put( Tuple_Index_Type'image( tuples( Q ) ) );
           put( " Rows" );
        end if;
        if wasNull then
           put( " with nulls" );
        end if;
        if columns( Q ) = 1 then
           put( " and 1 Column" );
        else
           put( " and" );
           put( integer'image( columns( Q ) ) );
           put( " Columns" );
        end if;
        new_line;
     end if;
     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end DBShowIt;

procedure ParseDBShow is
  -- Syntax: db.show;
  -- Source: N/A
begin
  expect( db_show_t );
  DBShowIt;
end ParseDBShow;

function pg_kind_to_string( kind : string ) return string is
-- convert the pg_class table's pg_relkind code to a readable string
begin
  if kind = "r" then
     return "table";
  elsif kind = "i" then
     return "index";
  elsif kind = "S" then
     return "sequence";
  elsif kind = "v" then
     return "view";
  elsif kind = "c" then
     return "composite type";
  elsif kind = "s" then
     return "special";
  elsif kind = "t" then
     return "TOAST table";
  end if;
  return "kind code " & kind;
end pg_kind_to_string;

function pg_column_type_to_string( kind, len : string ) return string is
-- convert the pg_class table's pg_relkind code to a readable string
begin
  if kind = "bpchar" then              -- blank-padded character array
     return "character(" & len & ")";  -- is char(n)
  elsif kind = "int4" then             -- 4-byte integer
     return "integer";                 -- is integer
  elsif kind = "varchar" then          -- varchar has a
     return "character varying(" & len & ")";   -- length
  elsif kind = "interval" then
     return kind;
  elsif kind = "timestamp" then
     return "timestamp without time zone";
  elsif kind = "int8" then
     return "bigint";
  elsif kind = "serial8" then
     return "bigserial";
  elsif kind = "bit" then
     return kind;
  elsif kind = "varbit" then
     return "bit varying(" & len & ")";   -- length
  elsif kind = "bool" then
     return "boolean";
  elsif kind = "box" then
     return kind;
  elsif kind = "bytea" then
     return kind;
  elsif kind = "cidr" then
     return kind;
  elsif kind = "circle" then
     return kind;
  elsif kind = "date" then
     return kind;
  elsif kind = "float8" then
     return "double precision";
  elsif kind = "inet" then
     return kind;
  elsif kind = "line" then
     return kind;
  elsif kind = "lseg" then
     return kind;
  elsif kind = "macaddr" then
     return kind;
  elsif kind = "money" then
     return kind;
  elsif kind = "decimal" then
     return kind;
  elsif kind = "path" then
     return kind;
  elsif kind = "point" then
     return kind;
  elsif kind = "polygon" then
     return kind;
  elsif kind = "float4" then
     return "real";
  elsif kind = "int2" then
     return "smallint";
  elsif kind = "serial4" then
     return "serial";
  elsif kind = "text" then
     return kind;
  elsif kind = "timetz" then
     return "time with time zone";
  elsif kind = "timestamptz" then
     return "timestamp with time zone";
  end if;
  return "type code " & kind;
end pg_column_type_to_string;

function pg_not_null_to_string( val : string ) return string is
-- convert a t/f value to "not null" like psql client
begin
  if val = "t" then
     return "not null";
  end if;
  return "";
end pg_not_null_to_string;

function pg_default_to_string( val : string ) return string is
-- convert a t/f value to "not null" like psql client
begin
  if val = "t" then
     return "default";
  end if;
  return "";
end pg_default_to_string;

function pg_userattributes_to_string( super, create : string ) return string is
-- convert t/f values to "superuser, create database" like psql client
begin
  if super = "t" and create = "t" then
     return "superuser, create database";
  elsif super = "t" then
     return "superuser";
  elsif create = "t" then
     return "create database";
  end if;
  return "";
end pg_userattributes_to_string;

procedure ParseDBList is
  -- Syntax: db.list
  -- Source: N/A
  tabularDisplay : boolean := false;
  headingWidth   : integer := 0;
  wasNull        : boolean := false;
  columnWidths   : array( 1..32 ) of integer;
  totalWidth     : integer;
  width          : integer;
begin
  expect( db_list_t );
  if isExecutingCommand then
     begin
     if is_connected( C ) then
        -- Show tablename and kind, lookup owner from another table.
        -- Don't show tables owned by postgres (user 1), TOAST tables or indexes
        prepare( Q, "select n.nspname as " & '"' & "Schema" & '"' &
          ", c.relname as " & '"' & "Name" & '"' &
          ", c.relkind as " & '"' & "Type" & '"' &
          ", u.usename as " &  '"' & "Owner" & '"' &
          " from pg_class c, pg_user u, pg_namespace n where u.usesysid = c.relowner and n.oid = c.relnamespace and c.relkind <> 't' and c.relkind <> 'i' and u.usesysid <> 1 order by c.relname" );
        execute( Q, C );

        -- Initially, the columns widths are the widths of the headings

        for i in 1..columns( Q ) loop
            columnWidths( i ) := column_name( Q, Column_Index_Type( i ) )'length;
            if columnWidths( i ) < 4 then -- room for NULL on tabular display
               columnWidths( i ) := 4;
            end if;
            if headingWidth < columnWidths( i ) then
               headingWidth := columnWidths( i );
            end if;
        end loop;

        -- Check query results and adjust the columns widths for the longest
        -- results.

        while not end_of_query( Q ) loop
              fetch( Q );
              for i in 1..columns( Q ) loop
                 if not is_null( Q, Column_Index_Type( i ) ) then
                    if i = 3 then -- column 2 is table type
                       width := length( to_unbounded_string( pg_kind_to_string( Value( Q, Column_Index_Type( i ) ) ) ) );
                    else
                       width := length( to_unbounded_string( Value( Q, Column_Index_Type( i ) ) ) );
                    end if;
                    if width > 256 then
                       width := 256;
                    end if;
                    if width > columnWidths( i ) then
                       columnWidths( i ) := width;
                    end if;
                 end if;
              end loop;
              exit when wasSIGINT;
        end loop;

        -- Add up all columns for the total width for a tabular display

        totalWidth := 2;                                        -- left/right marg
        for i in 1..columns( Q ) loop
            totalWidth := totalWidth + columnWidths( i );       -- width of column
            if i /= columns(Q) then                             -- not last col?
               totalWidth := totalWidth + 3;                    -- 3 char sep
            end if;
        end loop;

        -- Rewind the clear and prepare to show the results

        Rewind( Q );
        new_line;

        -- Use a tabular display only if will fit in the current display

        tabularDisplay := totalWidth <= integer( displayInfo.col );

        -- Draw the columns

        if tabularDisplay then
           put( " " );
           for i in 1..columns( Q ) loop
               put(
                  to_string(
                      Head(
                          to_unbounded_string(
                              column_name( Q, Column_Index_Type( i ) ) )
                      , columnWidths( i ) )
                  )
               );
               if i /= columns( Q ) then
                  put( " | " );
               end if;
           end loop;
           new_line;
           put( "-" );
           for i in 1..columns( Q ) loop
               put( to_string( columnWidths( i ) * "-" ) );
               if i /= columns( Q ) then
                  put( "-+-" );
               else
                  put( "-" );
               end if;
           end loop;
           new_line;
        end if;

        -- Draw the query results

        while not end_of_query( Q ) loop
            fetch( Q );
            if tabularDisplay then
               put( " " );
            end if;
            for i in 1..columns( Q ) loop
                if tabularDisplay then
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( to_string( Head( to_unbounded_string( "NULL" ), columnWidths( i ) ) ) ) );
                      wasNull := true;
                   elsif i = 3 then -- column 2 is table type
                      put( to_string( Head( ToEscaped( to_unbounded_string( pg_kind_to_string( value( Q, Column_Index_Type( i ) ) ) ) ), columnWidths( i ) ) ) );
                   else
                      put( to_string( Head( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                   end if;
                   if i /= columns( Q ) then
                      put( " | " );
                   end if;
                else
                   put( to_string( head( to_unbounded_string( column_name( Q, Column_Index_Type( i ) ) ), headingWidth ) ) );
                   put( ": " );
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( "NULL" ) );
                      wasNull := true;
                   elsif i = 3 then
                      put( bold( to_string( ToEscaped( to_unbounded_string( pg_kind_to_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) ) );
                   else
                      put( bold( to_string( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) );
                   end if;
                   new_line;
                end if;
            end loop;
            new_line;
            exit when wasSIGINT;
        end loop;
     end if;

     -- Draw the summary line

     if tuples( Q ) = 1 then
        put( " 1 Row" );
     else
        put( Tuple_Index_Type'image( tuples( Q ) ) );
        put( " Rows" );
     end if;
     if wasNull then
        put( " with nulls" );
     end if;
     if columns( Q ) = 1 then
        put( " and 1 Column" );
     else
        put( " and" );
        put( integer'image( columns( Q ) ) );
        put( " Columns" );
     end if;
     new_line;
     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBList;

procedure ParseDBSchema is
  -- Syntax: db.schema( "table" );
  -- Source: N/A
  tabularDisplay : boolean := false;
  headingWidth   : integer := 0;
  wasNull        : boolean := false;
  columnWidths   : array( 1..32 ) of integer;
  totalWidth     : integer;
  width          : integer;
  exprType       : identifier;
  exprVal        : unbounded_string;
begin
  expect( db_schema_t );
  expect( symbol_t, "(" );
  ParseExpression( exprVal, exprType );
  if baseTypesOK( exprType, string_t ) then
     expect( symbol_t, ")" );
  end if;
  if isExecutingCommand then
     begin
     if is_connected( C ) then
        -- Find column name, type, type length, not null and default flags
        -- Don't show dropped columns, columns with system types (oid, etc).
        prepare( Q, "select a.attname as " & '"' & "Column" & '"' &
                    ", t.typname as " & '"' & "Type" & '"' &
                    ", a.atttypmod-4 as " & '"' & "Length" & '"' &
                    ", a.attnotnull as " & '"' & "Not Null" & '"' &
                    ", a.atthasdef as " & '"' & "Default" & '"' &
                    "from pg_attribute a, pg_class c, pg_type t where a.attrelid = c.oid and t.oid = a.atttypid and a.attisdropped = 'f' and (a.atttypid < 26 or a.atttypid > 29) and c.relname='" &
                     to_string( exprVal ) & "' order by a.attnum" );
        execute( Q, C );

        -- No result? Then table was not found.

	if end_of_query( Q ) then
	   err( "Did not find any relation named " &
	     optional_bold( to_string( exprVal ) ) );
	   return;
	end if;
	
        -- Initially, the columns widths are the widths of the headings

        for i in 1..columns( Q ) loop
            if i /= 3 then -- column 3 is type length (not shown)
               columnWidths( i ) := column_name( Q, Column_Index_Type( i ) )'length;
               if columnWidths( i ) < 4 then -- room for NULL on tabular display
                  columnWidths( i ) := 4;
               end if;
               if headingWidth < columnWidths( i ) then
                  headingWidth := columnWidths( i );
               end if;
            end if;
        end loop;

        -- Check query results and adjust the columns widths for the longest
        -- results.

        while not end_of_query( Q ) loop
              fetch( Q );
              for i in 1..columns( Q ) loop
                 if i /= 3 then -- column 3 is type length (not shown)
                    if not is_null( Q, Column_Index_Type( i ) ) then
                       if i = 2 then -- column 2 is column type
                          width := length( to_unbounded_string(
                                   pg_column_type_to_string( Value( Q, Column_Index_Type( i ) ),
                                                             Value( Q, Column_Index_Type( i+1 ) ) ) ) );
                       elsif i = 4 then
                          width := length( to_unbounded_string(
                                   pg_not_null_to_string( Value( Q, Column_Index_Type( i ) ) ) ) );
                       elsif i = 5 then
                          width := length( to_unbounded_string(
                                   pg_default_to_string( Value( Q, Column_Index_Type( i ) ) ) ) );
                       else
                          width := length( to_unbounded_string( Value( Q, Column_Index_Type( i ) ) ) );
                       end if;
                       if width > 256 then
                          width := 256;
                       end if;
                       if width > columnWidths( i ) then
                          columnWidths( i ) := width;
                       end if;
                    end if;
                 end if;
              end loop;
        end loop;

        -- Add up all columns for the total width for a tabular display

        totalWidth := 2;                                        -- left/right marg
        for i in 1..columns( Q ) loop
            if i /= 3 then -- column 3 is type length (not shown)
               totalWidth := totalWidth + columnWidths( i );       -- width of column
               if i /= columns(Q) then                             -- not last col?
                  totalWidth := totalWidth + 3;                    -- 3 char sep
               end if;
            end if;
        end loop;

        -- Rewind the clear and prepare to show the results

        Rewind( Q );
        new_line;

        -- Use a tabular display only if will fit in the current display

        tabularDisplay := totalWidth <= integer( displayInfo.col );

        -- Draw the columns

        if tabularDisplay then
           put( " " );
           for i in 1..columns( Q ) loop
               if i /= 3 then -- column 3 is type length (not shown)
                  put(
                     to_string(
                         Head(
                             to_unbounded_string(
                                 column_name( Q, Column_Index_Type( i ) ) )
                         , columnWidths( i ) )
                     )
                  );
                  if i /= columns( Q ) then
                     put( " | " );
                  end if;
               end if;
           end loop;
           new_line;
           put( "-" );
           for i in 1..columns( Q ) loop
               if i /= 3 then -- column 3 is type length (not shown)
                  put( to_string( columnWidths( i ) * "-" ) );
                  if i /= columns( Q ) then
                     put( "-+-" );
                  else
                     put( "-" );
                  end if;
               end if;
           end loop;
           new_line;
        end if;

        -- Draw the query results

        while not end_of_query( Q ) loop
            fetch( Q );
            if tabularDisplay then
               put( " " );
            end if;
            for i in 1..columns( Q ) loop
                if i /= 3 then -- column 3 is type length (not shown)
                   if tabularDisplay then
                      if is_null( Q, Column_Index_Type( i ) ) then
                         put( inverse( to_string( Head( to_unbounded_string( "NULL" ), columnWidths( i ) ) ) ) );
                         wasNull := true;
                      elsif i = 2 then -- column 2 is column type
                         put( to_string( Head( ToEscaped( to_unbounded_string( pg_column_type_to_string( value( Q, Column_Index_Type( i ) ), Value( Q, Column_Index_Type( i+1 ) ) ) ) ), columnWidths( i ) ) ) );
                      elsif i = 4 then
                         put( to_string( Head( ToEscaped( to_unbounded_string( pg_not_null_to_string( value( Q, Column_Index_Type( i ) ) ) ) ), columnWidths( i ) ) ) );
                      elsif i = 5 then
                         put( to_string( Head( ToEscaped( to_unbounded_string( pg_default_to_string( value( Q, Column_Index_Type( i ) ) ) ) ), columnWidths( i ) ) ) );
                      else
                         put( to_string( Head( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                      end if;
                      if i /= columns( Q ) then
                         put( " | " );
                      end if;
                   else
                      put( to_string( head( to_unbounded_string( column_name( Q, Column_Index_Type( i ) ) ), headingWidth ) ) );
                      put( ": " );
                      if is_null( Q, Column_Index_Type( i ) ) then
                         put( inverse( "NULL" ) );
                         wasNull := true;
                      elsif i = 2 then
                         put( bold( to_string( ToEscaped( to_unbounded_string( pg_column_type_to_string( value( Q, Column_Index_Type( i ) ), Value( Q, Column_Index_Type( i+1 ) ) ) ) ) ) ) );
                      elsif i = 4 then
                         put( bold( to_string( ToEscaped( to_unbounded_string( pg_not_null_to_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) ) );
                      elsif i = 5 then
                         put( bold( to_string( ToEscaped( to_unbounded_string( pg_default_to_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) ) );
                      else
                         put( bold( to_string( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) );
                      end if;
                      new_line;
                   end if;
                end if;
            end loop;
            new_line;
        end loop;
     end if;

     -- Draw the summary line

     if tuples( Q ) = 1 then
        put( " 1 Row" );
     else
        put( Tuple_Index_Type'image( tuples( Q ) ) );
        put( " Rows" );
     end if;
     if wasNull then
        put( " with nulls" );
     end if;
     if columns( Q ) = 1 then
        put( " and 1 Column" );
     else
        put( " and" );
        put( integer'image( columns( Q ) ) );
        put( " Columns" );
     end if;
     new_line;
     prepare( Q, "select c.relname, i.indisprimary, i.indisunique, i.indkey from pg_index i, pg_class c" &
                 " where c.oid = i.indexrelid and i.indrelid in " &
                 " (select i.indrelid from pg_index, pg_class c2 where i.indrelid = c2.oid and c2.relname='" & to_string( exprVal ) & "') order by c.relname" );
     execute( Q, C );
     if tuples( Q ) > 0 then
        put_line( "Indexes:" );
        while not end_of_query( Q ) loop
            fetch( Q );
            put( "    " );
            declare
               indexName   : string := Value( Q, 1 );
               primaryKey  : string := Value( Q, 2 );
               uniqueIndex : string := Value( Q, 3 );
               colList     : string := Value( Q, 4 );
            begin
               put( bold( indexName ) );
               put( " " );
               if primaryKey = "t" then
                  put( "primary key " );
               end if;
               if uniqueIndex = "t" then
                  put( "unique " );
               end if;
               put( "on columns " );
               put( bold( colList ) );
            end;
            new_line;
        end loop;
     end if;

     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBSchema;

procedure ParseDBUsers is
  -- Syntax: db.users
  -- Source: N/A
  tabularDisplay : boolean := false;
  headingWidth   : integer := 0;
  wasNull        : boolean := false;
  columnWidths   : array( 1..32 ) of integer;
  totalWidth     : integer;
  width          : integer;
begin
  expect( db_users_t );
  if isExecutingCommand then
     begin
     if is_connected( C ) then
        -- Show tablename and kind, lookup owner from another table.
        -- Don't show tables owned by postgres (user 1), TOAST tables or indexes
        prepare( Q, "select usename as " & '"' & "User Name" & '"' &
                    ", usesysid as " & '"' & "User ID" & '"' &
                    ", usesuper as " & '"' & "Attributes" & '"' &
                    ", usecreatedb from pg_user order by usename" );
        execute( Q, C );

        -- Initially, the columns widths are the widths of the headings

        for i in 1..columns( Q ) loop
            columnWidths( i ) := column_name( Q, Column_Index_Type( i ) )'length;
            if columnWidths( i ) < 4 then -- room for NULL on tabular display
               columnWidths( i ) := 4;
            end if;
            if headingWidth < columnWidths( i ) then
               headingWidth := columnWidths( i );
            end if;
        end loop;

        -- Check query results and adjust the columns widths for the longest
        -- results.

        while not end_of_query( Q ) loop
              fetch( Q );
              for i in 1..columns( Q ) loop
                 if not is_null( Q, Column_Index_Type( i ) ) then
                    if i = 3 then -- column 3 and 4 are attributes
                       width := length( to_unbounded_string( pg_userattributes_to_string( Value( Q, Column_Index_Type( i ) ), Value( Q, Column_Index_Type( i ) ) ) ) );
                    elsif i = 4 then
                       null;
                    else
                       width := length( to_unbounded_string( Value( Q, Column_Index_Type( i ) ) ) );
                    end if;
                    if width > 256 then
                       width := 256;
                    end if;
                    if width > columnWidths( i ) then
                       columnWidths( i ) := width;
                    end if;
                 end if;
              end loop;
        end loop;

        -- Add up all columns for the total width for a tabular display

        totalWidth := 2;                                        -- left/right marg
        for i in 1..columns( Q ) loop
            totalWidth := totalWidth + columnWidths( i );       -- width of column
            if i /= columns(Q) then                             -- not last col?
               totalWidth := totalWidth + 3;                    -- 3 char sep
            end if;
        end loop;

        -- Rewind the clear and prepare to show the results

        Rewind( Q );
        new_line;

        -- Use a tabular display only if will fit in the current display

        tabularDisplay := totalWidth <= integer( displayInfo.col );

        -- Draw the columns

        if tabularDisplay then
           put( " " );
           for i in 1..columns( Q ) loop
               if i /= 4 then
                  put(
                     to_string(
                         Head(
                             to_unbounded_string(
                                 column_name( Q, Column_Index_Type( i ) ) )
                         , columnWidths( i ) )
                     )
                  );
                  if i /= 3 then
                     put( " | " );
                  end if;
               end if;
           end loop;
           new_line;
           put( "-" );
           for i in 1..columns( Q ) loop
               if i /= 4 then
                  put( to_string( columnWidths( i ) * "-" ) );
                  if i /= 3 then
                     put( "-+-" );
                  else
                     put( "-" );
                  end if;
               end if;
           end loop;
           new_line;
        end if;

        -- Draw the query results

        while not end_of_query( Q ) loop
            fetch( Q );
            if tabularDisplay then
               put( " " );
            end if;
            for i in 1..columns( Q ) loop
                if i /= 4 then
                   if tabularDisplay then
                      if is_null( Q, Column_Index_Type( i ) ) then
                         put( inverse( to_string( Head( to_unbounded_string( "NULL" ), columnWidths( i ) ) ) ) );
                         wasNull := true;
                      elsif i = 2 then -- right-aligned
                         put( to_string( Tail( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                      elsif i = 3 then -- column 3 and 4 are attributes
                         put( to_string( Head( ToEscaped( to_unbounded_string( pg_userattributes_to_string( value( Q, Column_Index_Type( i ) ), Value( Q, Column_Index_Type( i ) ) ) ) ), columnWidths( i ) ) ) );
                      else
                         put( to_string( Head( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                      end if;
                      if i /= 3 then
                         put( " | " );
                      end if;
                   else
                      put( to_string( head( to_unbounded_string( column_name( Q, Column_Index_Type( i ) ) ), headingWidth ) ) );
                      put( ": " );
                      if is_null( Q, Column_Index_Type( i ) ) then
                         put( inverse( "NULL" ) );
                         wasNull := true;
                      elsif i = 3 then -- column 3 and 4 are attributes
                         put( bold( to_string( ToEscaped( to_unbounded_string( pg_userattributes_to_string( value( Q, Column_Index_Type( i ) ), Value( Q, Column_Index_Type( i ) ) ) ) ) ) ) );
                      else
                         put( bold( to_string( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) );
                      end if;
                      new_line;
                   end if;
                end if;
            end loop;
            new_line;
        end loop;
     end if;

     -- Draw the summary line

     if tuples( Q ) = 1 then
        put( " 1 Row" );
     else
        put( Tuple_Index_Type'image( tuples( Q ) ) );
        put( " Rows" );
     end if;
     if wasNull then
        put( " with nulls" );
     end if;
     if columns( Q ) = 1 then
        put( " and 1 Column" );
     else
        put( " and" );
        put( integer'image( columns( Q ) ) );
        put( " Columns" );
     end if;
     new_line;
     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBUsers;

procedure ParseDBDatabases is
  -- Syntax: db.databases
  -- Source: N/A
  tabularDisplay : boolean := false;
  headingWidth   : integer := 0;
  wasNull        : boolean := false;
  columnWidths   : array( 1..32 ) of integer;
  totalWidth     : integer;
  width          : integer;
begin
  expect( db_databases_t );
  if isExecutingCommand then
     begin
     if is_connected( C ) then
        -- Show tablename and kind, lookup owner from another table.
        -- Don't show tables owned by postgres (user 1), TOAST tables or indexes
        prepare( Q, "select d.datname as " & '"' & "Name" & '"' &
                    ", u.usename as " & '"' & "Owner" & '"' &
                    " from pg_database d, pg_user u where u.usesysid = d.datdba order by d.datname" );
        execute( Q, C );

        -- Initially, the columns widths are the widths of the headings

        for i in 1..columns( Q ) loop
            columnWidths( i ) := column_name( Q, Column_Index_Type( i ) )'length;
            if columnWidths( i ) < 4 then -- room for NULL on tabular display
               columnWidths( i ) := 4;
            end if;
            if headingWidth < columnWidths( i ) then
               headingWidth := columnWidths( i );
            end if;
        end loop;

        -- Check query results and adjust the columns widths for the longest
        -- results.

        while not end_of_query( Q ) loop
              fetch( Q );
              for i in 1..columns( Q ) loop
                 if not is_null( Q, Column_Index_Type( i ) ) then
                    if i = 3 then -- column 2 is table type
                       width := length( to_unbounded_string( pg_kind_to_string( Value( Q, Column_Index_Type( i ) ) ) ) );
                    else
                       width := length( to_unbounded_string( Value( Q, Column_Index_Type( i ) ) ) );
                    end if;
                    if width > 256 then
                       width := 256;
                    end if;
                    if width > columnWidths( i ) then
                       columnWidths( i ) := width;
                    end if;
                 end if;
              end loop;
        end loop;

        -- Add up all columns for the total width for a tabular display

        totalWidth := 2;                                        -- left/right marg
        for i in 1..columns( Q ) loop
            totalWidth := totalWidth + columnWidths( i );       -- width of column
            if i /= columns(Q) then                             -- not last col?
               totalWidth := totalWidth + 3;                    -- 3 char sep
            end if;
        end loop;

        -- Rewind the clear and prepare to show the results

        Rewind( Q );
        new_line;

        -- Use a tabular display only if will fit in the current display

        tabularDisplay := totalWidth <= integer( displayInfo.col );

        -- Draw the columns

        if tabularDisplay then
           put( " " );
           for i in 1..columns( Q ) loop
               put(
                  to_string(
                      Head(
                          to_unbounded_string(
                              column_name( Q, Column_Index_Type( i ) ) )
                      , columnWidths( i ) )
                  )
               );
               if i /= columns( Q ) then
                  put( " | " );
               end if;
           end loop;
           new_line;
           put( "-" );
           for i in 1..columns( Q ) loop
               put( to_string( columnWidths( i ) * "-" ) );
               if i /= columns( Q ) then
                  put( "-+-" );
               else
                  put( "-" );
               end if;
           end loop;
           new_line;
        end if;

        -- Draw the query results

        while not end_of_query( Q ) loop
            fetch( Q );
            if tabularDisplay then
               put( " " );
            end if;
            for i in 1..columns( Q ) loop
                if tabularDisplay then
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( to_string( Head( to_unbounded_string( "NULL" ), columnWidths( i ) ) ) ) );
                      wasNull := true;
                   elsif i = 3 then -- column 2 is table type
                      put( to_string( Head( ToEscaped( to_unbounded_string( pg_kind_to_string( value( Q, Column_Index_Type( i ) ) ) ) ), columnWidths( i ) ) ) );
                   else
                      put( to_string( Head( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ), columnWidths( i ) ) ) );
                   end if;
                   if i /= columns( Q ) then
                      put( " | " );
                   end if;
                else
                   put( to_string( head( to_unbounded_string( column_name( Q, Column_Index_Type( i ) ) ), headingWidth ) ) );
                   put( ": " );
                   if is_null( Q, Column_Index_Type( i ) ) then
                      put( inverse( "NULL" ) );
                      wasNull := true;
                   elsif i = 3 then
                      put( bold( to_string( ToEscaped( to_unbounded_string( pg_kind_to_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) ) );
                   else
                      put( bold( to_string( ToEscaped( to_unbounded_string( value( Q, Column_Index_Type( i ) ) ) ) ) ) );
                   end if;
                   new_line;
                end if;
            end loop;
            new_line;
        end loop;
     end if;

     -- Draw the summary line

     if tuples( Q ) = 1 then
        put( " 1 Row" );
     else
        put( Tuple_Index_Type'image( tuples( Q ) ) );
        put( " Rows" );
     end if;
     if wasNull then
        put( " with nulls" );
     end if;
     if columns( Q ) = 1 then
        put( " and 1 Column" );
     else
        put( " and" );
        put( integer'image( columns( Q ) ) );
        put( " Columns" );
     end if;
     new_line;
     exception when no_tuple =>
       err( "no tuple" );
     when null_value =>
       err( "null value" );
     when no_column =>
       err( "no column" );
     when no_result =>
       err( "no result" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception was raised" );
     end;
  end if;
end ParseDBDatabases;

procedure DoSQLSelect( sqlcmd : unbounded_string ) is
begin
  if isExecutingCommand then
     prepare( Q, to_string( sqlcmd ) );
     DBShowIt;
  end if;
end DoSQLSelect;

procedure DoSQLStatement( sqlcmd : unbounded_string ) is
begin
  if isExecutingCommand then
     prepare( Q, to_string( sqlcmd ) );
     begin
       Execute( Q, C );
     exception when not_connected =>
       err( "not connected" );
     when abort_state =>
       err( "in abort state" );
     when sql_error =>
       err( Error_Message( Q ) );
     when others =>
       err( "exception raised" );
     end;
  end if;
end DoSQLStatement;

procedure StartupDB is
begin
  declareIdent( db_column_index_type_t, "db.column_index_type",
    positive_t, typeClass );

  declareIdent( db_tuple_index_type_t, "db.tuple_index_type",
    positive_t, typeClass );

  declareIdent( db_tuple_count_type_t, "db.tuple_count_type",
    db_tuple_index_type_t, subClass );

  declareIdent( db_trace_mode_type_t, "db.trace_mode_type",
    root_enumerated_t, typeClass );
  declareStandardConstant( db_trace_none_t, "db.trace_none",
    db_trace_mode_type_t, "0" );
  declareStandardConstant( db_trace_db_t, "db.trace_db",
    db_trace_mode_type_t, "1" );
  declareStandardConstant( db_trace_apq_t, "db.trace_apq",
    db_trace_mode_type_t, "2" );
  declareStandardConstant( db_trace_full_t, "db.trace_full",
    db_trace_mode_type_t, "3" );

  declareIdent( db_mode_type_t, "db.mode_type",
    root_enumerated_t, typeClass );
  declareStandardConstant( db_read_t, "db.read",
    db_mode_type_t, "0" );
  declareStandardConstant( db_write_t, "db.write",
    db_mode_type_t, "1" );
  declareStandardConstant( db_read_write_t, "db.read_write",
    db_mode_type_t, "2" );

  declareIdent( db_fetch_mode_type_t, "db.fetch_mode_type",
    root_enumerated_t, typeClass );
  declareStandardConstant( db_sequential_fetch_t, "db.sequential_fetch",
    db_fetch_mode_type_t, "0" );
  declareStandardConstant( db_random_fetch_t, "db.random_fetch",
    db_fetch_mode_type_t, "1" );

  declareIdent( db_database_type_t, "db.database_type",
    root_enumerated_t, typeClass );
  declareStandardConstant( db_engine_postgresql_t, "db.engine_postgresql",
    db_database_type_t, "0" );
  declareStandardConstant( db_engine_mysql_t, "db.engine_mysql",
    db_database_type_t, "1" );
  declareStandardConstant( db_engine_oracle_t, "db.engine_oracle",
    db_database_type_t, "2" );
  declareStandardConstant( db_engine_sybase_t, "db.engine_sybase",
    db_database_type_t, "3" );
  declareStandardConstant( db_engine_db2_t, "db.engine_db2",
    db_database_type_t, "4" );

  declareProcedure( db_connect_t, "db.connect" );
  declareProcedure( db_disconnect_t, "db.disconnect" );
  declareFunction( db_is_connected_t, "db.is_connected" );
  declareProcedure( db_reset_t, "db.reset" );
  declareFunction( db_error_message_t, "db.error_message" );
  declareFunction( db_notice_message_t, "db.notice_message" );
  declareFunction( db_in_abort_state_t, "db.in_abort_state" );
  declareFunction( db_options_t, "db.options" );
  declareFunction( db_will_rollback_on_finalize_t, "db.will_rollback_on_finalize" );
  declareProcedure( db_set_rollback_on_finalize_t, "db.set_rollback_on_finalize" );
  declareProcedure( db_open_db_trace_t, "db.open_db_trace" );
  declareProcedure( db_close_db_trace_t, "db.close_db_trace" );
  declareProcedure( db_set_trace_t, "db.set_trace" );
  declareFunction( db_is_trace_t, "db.is_trace" );
  declareProcedure( db_clear_t, "db.clear" );
  declareProcedure( db_prepare_t, "db.prepare" );
  declareProcedure( db_append_t, "db.append" );
  declareProcedure( db_append_line_t, "db.append_line" );
  declareProcedure( db_append_quoted_t, "db.append_quoted" );
  declareProcedure( db_execute_t, "db.execute" );
  declareProcedure( db_execute_checked_t, "db.execute_checked" );
  declareProcedure( db_raise_exceptions_t, "db.raise_exceptions" );
  declareProcedure( db_report_errors_t, "db.report_errors" );
  declareProcedure( db_begin_work_t, "db.begin_work" );
  declareProcedure( db_commit_work_t, "db.commit_work" );
  declareProcedure( db_rollback_work_t, "db.rollback_work" );
  declareProcedure( db_rewind_t, "db.rewind" );
  declareProcedure( db_fetch_t, "db.fetch" );
  declareFunction( db_end_of_query_t, "db.end_of_query" );
  declareFunction( db_tuple_t, "db.tuple" );
  declareFunction( db_tuples_t, "db.tuples" );
  declareFunction( db_columns_t, "db.columns" );
  declareFunction( db_column_name_t, "db.column_name" );
  declareFunction( db_column_index_t, "db.column_index" );
  declareFunction( db_column_type_t, "db.column_type" );
  declareFunction( db_is_null_t, "db.is_null" );
  declareFunction( db_value_t, "db.value" );
  declareFunction( db_engine_of_t, "db.engine_of" );
  declareProcedure( db_show_t, "db.show" );
  declareProcedure( db_list_t, "db.list" );
  declareProcedure( db_schema_t, "db.schema" );
  declareProcedure( db_users_t, "db.users" );
  declareProcedure( db_databases_t, "db.databases" );

  --declareFunction( db_do_t, "db.do" );
  --declareFunction( db_fetchrow_t, "dbi.fetchrow" );

  --declareFunction( dbi_prepare_t, "dbi.prepare" );

end StartupDB;

procedure ShutdownDB is
begin
  null;
end ShutdownDB;

end parser_db;
