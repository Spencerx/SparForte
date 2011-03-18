
procedure minimal_cgi is
  -- Demonstrate SparFortes CGI interface
  -- based on AdaCGI's minimal.adb example

  -- To run this script directly (without a HTTP server), set the
  -- environment variable REQUEST_METHOD to "GET" and the variable
  -- QUERY_STRING to either "" or "x=a&y=b".

begin
  -- cgi.put_cgi_header defaults to "content-type" but should do "Content-type"
  cgi.put_cgi_header( "Content-type: text/html" );
  cgi.put_html_head( "Minimal Form Demonstration" );
  if cgi.input_received then
     cgi.put_variables;
  else
     put_line( "<form method=" & ASCII.Quotation & "POST" & ASCII.Quotation &
       ">What's your name?<input name=" & ASCII.Quotation & "username" &
       ASCII.Quotation & "><input type=" & ASCII.Quotation & "submit" &
       ASCII.Quotation & "></form>" );
  end if;
  cgi.put_html_tail;
end minimal_cgi;
