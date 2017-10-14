#!/usr/local/bin/spar

pragma annotate( summary, "sumseries" )
              @( description, "Compute the nth term of a series, i.e. the " )
              @( description, "sum of the n first terms of the " )
              @( description, "corresponding sequence.  For this task " )
              @( description, "repeat 1000 times. " )
              @( see_also, "http://rosettacode.org/wiki/Sum_of_a_series" )
              @( author, "Ken O. Burtch" );
pragma license( unrestricted );

pragma restriction( no_external_commands );

procedure sumseries is

  function inverse_square( x : long_float ) return long_float is
  begin
    return 1/x**2;
  end inverse_square;

sum : long_float := 0.0;
max_param : natural := 1000;

begin
  for i in 1..max_param loop
    sum := @ + inverse_square( i );
  end loop;

  put( "Sum of F(x) from 1 to" )
    @( max_param )
    @( " is" )
    @( sum );
  new_line;
end sumseries;

-- VIM editor formatting instructions
-- vim: ft=spar

