#!/bin/bash

SCRIPT_SOURCE=`dirname $BASH_SOURCE[0]`
. $SCRIPT_SOURCE/_gscripts_common.sh

load_gscripts_config

function conn_ok()
{
    if (("$#"==0))
    then
	echo "Connected"
	exit 0
    else
	$@
    fi
}

function conn_ko()
{
    # if (("$#"==0))
    # then
	echo "Not connected"
	exit 1
    # else
    # 	Alternative exec
    # fi
}

error=$( { LC_ALL=C echo "">/dev/tcp/$PING_SERVER/80; } 2>&1 )

if [ -z "$error" ]
then 
    conn_ok $@
elif [ -n "`echo $error | grep 'No such file or directory'`" ]
then
    # Use another method because /dev/tcp is not supported
    if ping -c1 $PING_SERVER &>/dev/null 
    then 
	conn_ok $@
    else 
	conn_ko $@
    fi
else
    conn_ko $@
fi
