------------------------------------------------------------------------------
-- Common declarations across most of BUSH including                        --
-- command line switches and the symbol table.                              --
--                                                                          --
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
-- CVS: $Id: world.ads,v 1.5 2005/08/31 15:10:45 ken Exp $

with system,
  ada.numerics.float_random,
  ada.unchecked_deallocation,
  ada.strings.unbounded,
  gen_list,
  APQ;
use ada.strings.unbounded, APQ;


package world is

------------------------------------------------------------------------------
-- Global Variables / Flags
------------------------------------------------------------------------------

version   : constant string := "1.2";
copyright : constant string :=  " Copyright (c)2001-2010 PegaSoft Canada & Free Software Foundation";

random_generator : ada.numerics.float_random.generator;

--
-- Decimal type for formatted numbers
--

type integerOutputType is delta 0.1 digits System.Max_Digits-2;
--   delta can't be 1, so we'll settle for 0.1.  This is the largest
--   long float number we can convert to an integer (and vice vera)
--   without rounding or resorting to scientific notation.  Why
--   -2? Anything higher resulted in rounding of Max_Int and Min_Int.

type anInputMode is ( interactive, breakout, fromScriptFile );
-- interactive - user is typing commands from the prompt
-- fromScriptFile - commands are executing from a script file

type identifier is new integer range 1..2750;
-- identifiers are identified by a unique number.  The upper bound indicates
-- the number of identifiers that can be declared.


------------------------------------------------------------------------------
-- Modes
------------------------------------------------------------------------------

trace            : boolean := false;      -- true if trace is on
inputMode        : anInputMode := interactive;
syntax_check     : boolean := false;      -- true if syntax checking
breakoutContinue : boolean := false;      -- true if execution should continue
isLoginShell     : boolean := false;      -- true if a login shell
stepFlag1        : boolean := false;      -- first parser step cmd flag
stepFlag2        : boolean := false;      -- second parser step cmd flag


------------------------------------------------------------------------------
-- Scanning
------------------------------------------------------------------------------

type aLineNumber is new natural;          -- a byte code line number
type aStatusCode is new integer;          -- a shell status code

token       : identifier;                 -- item we're currently looking at

done        : boolean := false;           -- true if exiting script
error_found : boolean := false;           -- true if an error occurred
done_sub    : boolean := false;           -- true if done a subprogram
exit_block  : boolean := false;           -- true if "exit"ing
last_status : aStatusCode := 0;           -- status of last shell command

-- Source Files List
--
-- The byte code compiler permits for multiple source files to be built at
-- one time (though there is no way to specify multiple source files yet).
-- We need to maintain a globally-accessible linked list of the names of
-- loaded source files to identify where byte code lines originated from.
-- We're using a record for allow storing additional information in the future.

type aSourceFile is record                -- source file info
     name : unbounded_string;             -- name of the source file
end record;

function ">"( left, right : aSourceFile ) return boolean;

package SourceFilesList is new gen_list( aSourceFile, ">", "=" );

sourceFiles : SourceFilesList.List;
-- the list of source files

commandLineSource : constant string := "Command";
-- name for a "script" (command) typed at the command prompt

------------------------------------------------------------------------------
-- Error Handling
------------------------------------------------------------------------------

-- error_type    : anExceptionType;          -- type of exception
err_message : unbounded_string;         -- last error message

------------------------------------------------------------------------------
-- Pragma Flags
------------------------------------------------------------------------------

onlyAda95                        : boolean := false; -- pragma ada_95
restriction_no_auto_declarations : boolean := false; -- pragma restriction
restriction_no_external_commands : boolean := false; -- pragma restriction
no_command_hash                  : boolean := false;

type templateTypes is (noTemplate, htmlTemplate, textTemplate);

processingTemplate        : boolean := false; -- pragma tempate
unrestrictedTemplate      : boolean := false; -- pragma unrestricted_t
templatePath              : unbounded_string; -- template path
templateType              : templateTypes;

depreciatedMsg : unbounded_string := null_unbounded_string; -- pragma dep.


------------------------------------------------------------------------------
-- Command Line Options
--
-- These are set when BUSH interprets its command line options
------------------------------------------------------------------------------

type commandLineOption is new boolean;

breakoutOpt  : commandLineOption := false;           -- true if -b
syntaxOpt    : commandLineOption := false;           -- true if -c
debugOpt     : commandLineOption := false;           -- true if -d
execOpt      : commandLineOption := false;           -- true if -e
gccOpt       : commandLineOption := false;           -- true if -g
importOpt    : commandLineOption := false;           -- true if -i
nosyntaxOpt  : commandLineOption := false;           -- true if -n
rshOpt       : commandLineOption := false;           -- true if -r
verboseOpt   : commandLineOption := false;           -- true if -v
traceOpt     : commandLineOption := false;           -- true if -x

--optionOffset : natural := 0;     -- character offset to script parameters

terminalWindowNaming : boolean := false;
-- true if terminal emulation supports xterm window naming

currentEngine : Database_Type := Engine_PostgreSQL;
engineOpen    : boolean := false;
-- current database being used.  Unfortunately, APQ has no Engine_None so we
-- need two variables.

------------------------------------------------------------------------------
-- Identifiers (The Symbol Table)
--
------------------------------------------------------------------------------
--
-- Identifier classes
--
--   constClass    - a constant
--   subClass      - a subtype
--   typeClass     - a type
--   funcClass     - a function
--   procClass     - a procedure
--   userProcClass - a user-defined procedure
--   taskClass     - a task
--   otherClass    - a variable (probably needs a more descriptive name)

type anIdentifierClass is ( constClass, subClass, typeClass, funcClass,
  userFuncClass, procClass, userProcClass, taskClass, mainProgramClass,
  otherClass );

 
------------------------------------------------------------------------------
-- Identifier Declarations
--
------------------------------------------------------------------------------

type declaration is record
     name     : unbounded_string                -- identifier name
                := Null_Unbounded_String;
     kind     : identifier;                     -- identifier's type
     value    : unbounded_string                -- identifier's value
                := Null_Unbounded_String;
     class    : anIdentifierClass               -- identifier's class
                := otherClass;
     import   : boolean := false;               -- marked by pragma import
     export   : boolean := false;               -- marked by pragma export
     volatile : boolean := false;               -- marked by pragma volatile
     limit    : boolean := false;               -- limited type
     list     : boolean := false;               -- array or array type
     field_of : identifier;                     -- record superclass
     inspect  : boolean := false;               -- show value on breakout
     deleted  : boolean := false;               -- marked for deletion
end record;


------------------------------------------------------------------------------
-- Symbol Table
--
------------------------------------------------------------------------------

type identifiersArray is array ( identifier ) of declaration;

identifiers     : identifiersArray;
identifiers_top : identifier := identifier'first;
keywords_top    : identifier := identifier'last;
reserved_top    : identifier := identifier'last;
-- this arrangement means the last array element is never accessed

-- "Captain, the ship can't take any more!"

symbol_table_overflow : exception;


------------------------------------------------------------------------------
-- Predefined Identifiers (Global)
--
-- These identifiers always have meaning and are accessible from all other
-- packages.  They represent keywords and other unchangable declarations
-- in the symbol table.
--
-- Keyword is the root of all identifiers in the symbol table tree.  It is
-- the type for any AdaScript keyword.
------------------------------------------------------------------------------

keyword_t : identifier;


------------------------------------------------------------------------------
-- Keywords
--
-- All Ada95 keywords are reserved even if they are not used by AdaScript
------------------------------------------------------------------------------

abort_t    : identifier;
abs_t      : identifier;
abstract_t : identifier;
accept_t   : identifier;
access_t   : identifier;
aliased_t  : identifier;
all_t      : identifier;
and_t      : identifier;
array_t    : identifier;
at_t       : identifier;
begin_t    : identifier;
body_t     : identifier;
case_t     : identifier;
constant_t : identifier;
declare_t  : identifier;
delay_t    : identifier;
delta_t    : identifier;
digits_t   : identifier;
do_t       : identifier;
else_t     : identifier;
elsif_t    : identifier;
end_t      : identifier;
entry_t    : identifier;
exception_t : identifier;
exit_t     : identifier;
for_t      : identifier;
function_t : identifier;
generic_t  : identifier;
goto_t     : identifier;
if_t       : identifier;
in_t       : identifier;
interface_t : identifier;
is_t       : identifier;
limited_t  : identifier;
loop_t     : identifier;
mod_t      : identifier;
new_t      : identifier;
not_t      : identifier;
null_t     : identifier;
of_t       : identifier;
or_t       : identifier;
others_t   : identifier;
out_t      : identifier;
package_t  : identifier;
pragma_t   : identifier;
private_t  : identifier;
procedure_t : identifier;
protected_t : identifier;
raise_t    : identifier;
range_t    : identifier;
record_t   : identifier;
rem_t      : identifier;
renames_t  : identifier;
requeue_t  : identifier;
return_t   : identifier;
reverse_t  : identifier;
select_t   : identifier;
separate_t : identifier;
subtype_t  : identifier;
tagged_t   : identifier;
task_t     : identifier;
terminate_t : identifier;
then_t     : identifier;
type_t     : identifier;
until_t    : identifier;
use_t      : identifier;
when_t     : identifier;
while_t    : identifier;
with_t     : identifier;
xor_t      : identifier;


------------------------------------------------------------------------------
--  Built-in Bourne shell commands
--
-- AdaScript shell commands that extend Ada 95 are also reserved words
------------------------------------------------------------------------------

env_t      : identifier;
typeset_t  : identifier;
unset_t    : identifier;
trace_t    : identifier;
help_t     : identifier;
clear_t    : identifier;
jobs_t     : identifier;
logout_t   : identifier;
pwd_t      : identifier;  -- built-in pwd
cd_t       : identifier;  -- built-in cd
wait_t     : identifier;  -- built-in wait
step_t     : identifier;
-- template_t : identifier;
history_t  : identifier;  -- built-in history

------------------------------------------------------------------------------
--  Built-in SQL commands
--
------------------------------------------------------------------------------

alter_t  : identifier;
insert_t : identifier;
-- delete_t : identifier; (shared with Ada delete declared above)
-- select_t : identifier; (shared with Ada select declared above)
update_t : identifier;

------------------------------------------------------------------------------
-- Other internal identifiers
--
-- EOF token, literals and virtual machine instructions.  Users should never
-- see these but they are all defined in the symbol table.
------------------------------------------------------------------------------

eof_t      : identifier;  -- end of file / abort script
symbol_t   : identifier;  -- punctuation/etc., value = string of punctuation
backlit_t  : identifier;  -- back quoted literal, value = the literal
strlit_t   : identifier;  -- string literal, value = the literal
charlit_t  : identifier;  -- character literal, value = the literal
number_t   : identifier;  -- numeric literal, value = the literal
imm_delim_t: identifier;  -- immediate word delimiter / identifier terminator
imm_sql_delim_t: identifier;  -- same for SQL word
word_t     : identifier;  -- immediate word value
sql_word_t : identifier;  -- a SQL word (not to be escaped)
char_escape_t : identifier; -- character escape


------------------------------------------------------------------------------
-- Predefined types
--
-- All Ada 95 fundamental types are declared, as well as AdaScript extensions.
--
-- variable_t is the root type of all variables and
-- is only used to mark the fundamental types.
--
-- the fundamental types are univeral number, universal
-- string and universal (typeless).  All have .kind =
-- variable_t.
--
-- the basic Ada types are derived from the universal
-- types and have a .kind = some univeral type.
--
-- user types are, of course, derived from the basic
-- Ada types and have a .kind = some basic Ada type
------------------------------------------------------------------------------

variable_t            : identifier;

uni_numeric_t         : identifier;
uni_string_t          : identifier;
universal_t           : identifier;
root_enumerated_t     : identifier;
root_record_t         : identifier;
command_t             : identifier;

file_type_t           : identifier;
socket_type_t         : identifier;
integer_t             : identifier;
natural_t             : identifier;
positive_t            : identifier;
short_short_integer_t : identifier;
short_integer_t       : identifier;
long_integer_t        : identifier;
long_long_integer_t   : identifier;
character_t           : identifier;
float_t               : identifier;
short_float_t         : identifier;
long_float_t          : identifier;
boolean_t             : identifier;
string_t              : identifier;
duration_t            : identifier;
file_mode_t           : identifier;
unbounded_string_t    : identifier;
complex_t             : identifier;
complex_real_t        : identifier;
complex_imaginary_t   : identifier;

false_t               : identifier; -- Boolean.false
true_t                : identifier; -- Boolean.true

------------------------------------------------------------------------------
-- Shortcut operands
--
-- The reflexive operand, itself, "@":
--
--   If itself's class is otherClass, it refers to a variable.
--     eg. total := @+1;  itself is the value, itself_type is the type
--   If itself's class is procClass, it refers to a procedure.
--     eg. put( "hello" ) @ ( "!" )  itself_type is the procedure id and
--     itself is unused
--   If itself_type is new_t, then itself is undefined.
--   To extend itself's capabilities, beware of side-effects.
------------------------------------------------------------------------------

itself      : unbounded_string;   -- copy of the identifier declaration
itself_type : identifier;         -- type of @ or procedure identifier

-- The last output operand, %

last_output : unbounded_string;   -- result of last output
last_output_type : identifier;    -- type of last output


------------------------------------------------------------------------------
-- Declarations
------------------------------------------------------------------------------

procedure declareKeyword( id : out identifier; s : string );
-- initialize a new keyword / internal identifier

procedure declareFunction( id : out identifier; s : string );
-- Initialize a built-in function identifier in the symbol table

procedure declareProcedure( id : out identifier; s : string );
-- Initialize a built-in procedure identifier in the symbol table

function deleteIdent( id : identifier ) return boolean;
-- delete an identifier, true if successful

procedure declareIdent( id : out identifier; name : unbounded_string;
  kind : identifier; class : anIdentifierClass := otherClass );
-- Declare an identifier in the symbol table, specifying name, kind.
-- and (optionally) symbol class.  The id is returned.

procedure declareIdent( id : out identifier; name : string;
  kind : identifier; class : anIdentifierClass := otherClass );
-- Alternate version: use fixed string type for name

procedure declareStandardConstant( id : out identifier;
   name : string; kind : identifier; value : string );
-- Declare a standard constant in the symbol table.  The id is not
-- returned since we don't change with constants once they are set.

procedure declareStandardConstant( name : string; kind : identifier;
  value : string );
-- Alternative version: return the symbol table id

procedure updateFormalParameter( id : identifier; kind : identifier;
  proc_id : identifier; parameterNumber : integer );
-- Update a formal parameter (ie. proc.param).  The id is not
-- returned since we don't change the formal parameters once they are set.

procedure declareActualParameter( id : out identifier;
proc_id : identifier; parameterNumber : integer;
value : unbounded_string );
-- Declare an actual parameter (ie. param for proc.param).  

procedure declareReturnResult( id : out identifier; func_id : identifier );
-- Declare space for the function return result.

procedure findIdent( name : unbounded_string; id : out identifier );
-- find an identifier, eof_t if failed

procedure init_env_ident( s : string );
-- initialize an environment variable

function is_keyword( id : identifier ) return boolean;
-- TRUE if the identifier is a keyword

-----------------------------------------------------------------------------
-- Type Representation
-----------------------------------------------------------------------------

maxInteger : long_float;
-- equivalent to BUSH's System.Max_Int, the largest integer representable
-- by BUSH (it is not long_integer'last).  Set during scanner startup.

function to_numeric( s : unbounded_string ) return long_float;
-- Convert an unbounded string to a long float (BUSH's numeric representation)

function to_numeric( id : identifier ) return long_float;
-- Look up an identifier's value and return it as a long float
-- (BUSH's numeric representation).

function to_bush_boolean( AdaBoolean : boolean ) return unbounded_string;
  -- convert an Ada boolean into a BUSH boolean (a string containing
  -- the position, no leading blank).

function to_unbounded_string( f : long_float ) return unbounded_string;
-- convert a numeric value to a bush string, dropping of decimal portion
-- if a small integer

-----------------------------------------------------------------------------
-- Character Conversion
-----------------------------------------------------------------------------

function toHighASCII( ch : character ) return character;
function toHighASCII( id : identifier ) return character;
-- add 128 to a character

function toLowASCII( ch : character ) return character;
function toLowASCII( id : identifier ) return character;
-- subtract 128 from a character

-----------------------------------------------------------------------------
-- Shell Words
-----------------------------------------------------------------------------

type aShellWordType is (
     normalWord,           -- any word that is not a special word
     semicolonWord,        -- unescaped ;
     pipeWord,             -- unescaped |
     ampersandWord,        -- unescaped &
     redirectOutWord,      -- unescaped >
     redirectInWord,       -- unescaped <
     redirectAppendWord,   -- unescaped >>      redirectErrOutWord,   -- unescaped 2>
     redirectErrOutWord,   -- unescaped 2>
     redirectErrAppendWord,-- unescaped 2>>
     redirectErr2OutWord,  -- unescaped 2>&1
     itselfWord            -- unescaped @
);
-- To differentiate between ";" and ;, "|" and |, "&" and &, etc.
                                                                                

type aShellWord is record
     wordType : aShellWordType;                       -- shell token type
     pattern  : unbounded_string;                     -- pattern for word
     word     : unbounded_string;                     -- expanded word
end record;

nullShellWord : aShellWord := ( normalWord, null_unbounded_string,
  null_unbounded_string );

function ">"( left, right : aShellWord ) return boolean;

package shellWordList is new gen_list( aShellWord, ">", "=" );

-- Enviroment
--
-- Since the O/S environment is altered while BUSH is running, save the initial
-- environment in a linked list when BUSH starts.  This is the list.

package environmentList is new gen_list( unbounded_string, ">", "=" );

initialEnvironment : environmentList.List;

-- Find fieldNumber'th field of a record varable. 

procedure findField( recordVar : identifier; fieldNumber: natural;
  fieldVar : out identifier );

end world;
