#!/bin/bash
#
# Build System Tests
# ---------------------------------------------------------------------------

cd ../..

# Make without Berkeley DB
# ---------------------------------------------------------------------------

make distclean
./configure --without-bdb
make all
if [ $? -ne 0 ] ; then
   echo "failed"
fi
TMP=`src/spar -e "f : btree_io.file; ? btree_io.is_open( f );"`
if [ "$TMP" = "false" ] ; then
   echo "without-bdb failed"
   exit 192
fi

# Make both MySQL and PostgreSQL
# ---------------------------------------------------------------------------

make distclean
./configure
make all
if [ $? -ne 0 ] ; then
   echo "failed"
fi
TMP=`src/spar -e "? mysql.is_connected;"`
if [ "$TMP" != "false" ] ; then
   echo "defaults failed"
   exit 192
fi
TMP=`src/spar -e "? db.is_connected;"`
if [ "$TMP" != "false" ] ; then
   echo "defaults failed"
   exit 192
fi

# Make without MySQL
# ---------------------------------------------------------------------------

make distclean
./configure --without-mysql
make all
if [ $? -ne 0 ] ; then
   echo "failed"
fi
TMP=`src/spar -e "? mysql.is_connected;"`
if [ "$TMP" = "false" ] ; then
   echo "without-mysql failed"
   exit 192
fi
TMP=`src/spar -e "? db.is_connected;"`
if [ "$TMP" != "false" ] ; then
   echo "without-mysql failed"
   exit 192
fi

# Make without PostgreSQL
# ---------------------------------------------------------------------------

make distclean
./configure --without-postgres
make all
if [ $? -ne 0 ] ; then
   echo "failed"
fi
TMP=`src/spar -e "? mysql.is_connected;"`
if [ "$TMP" != "false" ] ; then
   echo "without-postgres failed"
   exit 192
fi
TMP=`src/spar -e "? db.is_connected;"`
if [ "$TMP" = "false" ] ; then
   echo "without-postgres failed"
   exit 192
fi

# Make without MySQL and PostgreSQL
# ---------------------------------------------------------------------------

make distclean
./configure --without-mysql --without-postgres
make all
if [ $? -ne 0 ] ; then
   echo "failed"
fi

TMP=`src/spar -e "? mysql.is_connected;"`
if [ "$TMP" = "false" ] ; then
   echo "without-mysql without-postgres failed"
   exit 192
fi
TMP=`src/spar -e "? db.is_connected;"`
if [ "$TMP" = "false" ] ; then
   echo "without-mysql without-postgres failed"
   exit 192
fi

# Make without Readline
# ---------------------------------------------------------------------------

make distclean
./configure --without-readline
make all
if [ $? -ne 0 ] ; then
   echo "without-readline failed"
fi
# TODO: readline not checked by running spar.  an easy way??

# Make without Sound
# ---------------------------------------------------------------------------

make distclean
./configure --without-sound
make all
if [ $? -ne 0 ] ; then
   echo "without-sound failed"
fi
# TODO: sound not checked by running spar.

# Make without OpenGL
# ---------------------------------------------------------------------------

make distclean
./configure --without-opengl
make all
if [ $? -ne 0 ] ; then
   echo "without-opengl failed"
fi
# TODO: sound not checked by running spar.

# Cleanup

make distclean
echo "BUILD SYSTEM TESTS ARE OK"
exit 0

