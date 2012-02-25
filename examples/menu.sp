#!/bin/bush

trace false;

declare
  reply     : universal_typeless := 0; -- user's reply
  showMenu  : boolean := true;         -- true if menu is shown before prompt
  directory : string := ".";           -- current directory to list
begin

while true loop

  if showMenu then
     put_line( "Main Menu" );
     new_line;
     put_line( "1. ls" );
     put_line( "2. ls -l" );
     put_line( "3. change directory" );
     put_line( "4. SparForte tracing on" );
     put_line( "5. SparForte tracing off" );
     put_line( "6. quit" );
     new_line;
     put_line( "The current directory is " & directory );
     new_line;
     showMenu := false;
  end if;

  put( "==> " );
  reply := get_line;
  if reply = 1 then
     cd (directory) ; ls;
  elsif reply = 2 then
     cd (directory) ; ls -l;
  elsif reply = 3 then
     put( "New directory?" );
     directory := get_line;
  elsif reply = 4 then
     trace true;
  elsif reply = 5 then
     trace false;
  elsif reply = 6 then
     exit;
  else
     put_line( "Please type a number between 1 and 6" );
     new_line;
     showMenu;
  end if;
end loop;

put_line( "Bye!" );

end; -- script

