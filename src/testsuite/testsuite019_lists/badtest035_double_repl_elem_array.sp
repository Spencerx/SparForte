l1 : doubly_linked_lists.list( integer );
c1 : doubly_linked_lists.cursor( integer );
a  : array(0..1) of integer;
doubly_linked_lists.append( l1, 1234 );
doubly_linked_lists.append( l1, 2345 );
doubly_linked_lists.last( l1, c1 );
doubly_linked_lists.replace_element( l1, c1, a ); -- should be integer

