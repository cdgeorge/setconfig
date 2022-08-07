#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SETCONFIG=$SCRIPT_DIR/../setconfig.pl
TEST_AREA=/tmp/setconfig-test
rm -rf $TEST_AREA
mkdir -p $TEST_AREA

$SETCONFIG --help
set -x
cp $SCRIPT_DIR/test-files/smb.conf $TEST_AREA
cp $SCRIPT_DIR/test-files/smb.setconfig $TEST_AREA
$SETCONFIG --set-from $TEST_AREA/smb.setconfig --cfg-file $TEST_AREA/smb.conf
diff -U3 $SCRIPT_DIR/test-files/smb.conf $TEST_AREA/smb.conf >$TEST_AREA/t1.diff
$SETCONFIG --set-from $TEST_AREA/smb.setconfig --cfg-file $TEST_AREA/smb.conf
diff -U3 $SCRIPT_DIR/test-files/smb.conf $TEST_AREA/smb.conf >$TEST_AREA/t2.diff
diff $TEST_AREA/t1.diff $TEST_AREA/t2.diff

$SETCONFIG --revert --cfg-file $TEST_AREA/smb.conf
diff -U3 $SCRIPT_DIR/test-files/smb.conf $TEST_AREA/smb.conf





rm -rf $TEST_AREA

