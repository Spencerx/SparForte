#!/usr/local/bin/spar

pragma annotate( summary, "loopsbreak" )
              @( description, "Show a loop which prints random numbers (each number newly" )
              @( description, "generated each loop) from 0 to 19 (inclusive). If a number is" )
              @( description, "10, stop the loop after printing it, and do not generate any" )
              @( description, "further numbers. Otherwise, generate and print a second random" )
              @( description, "number before restarting the loop. If the number 10 is never" )
              @( description, "generated as the first number in a loop, loop forever. " )
              @( category, "tutorials" )
              @( author, "Ken O. Burtch" )
              @( see_also, "http://rosettacode.org/wiki/Loops/Break" );
pragma license( unrestricted );

pragma software_model( nonstandard );
pragma restriction( no_external_commands );

procedure arraysloop is
  a : positive;
  b : positive;
begin
  loop
    a := numerics.rnd( 20 );
    put_line( strings.image( a ) );
    exit when a = 10;
    b := numerics.rnd( 20 );
    put_line( strings.image( b ) );
  end loop;
end arraysloop;

-- VIM editor formatting instructions
-- vim: ft=spar

