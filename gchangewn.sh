#!/bin/bash
WMCTRL=`which wmctrl`
ZENITY=`which zenity`
NOTIFY_SEND=`which notify-send`
NOTIFY_SEND_ARGS="-t 2000 -i window-duplicate"

SCRIPT_SOURCE=`dirname $BASH_SOURCE[0]`
. $SCRIPT_SOURCE/_gscripts_common.sh

function get_window()
{
	if [ "$1" == "Using" ]; then
		WINDOWLIST="`$WMCTRL -l`"
		if [ -z "`echo $WINDOWLIST | grep $3`" ]; then
			$ZENITY --error --text "$(__ "Couldn't find selected window")"
			exit
		fi
		NEWTITLE="`zenity --entry --width 350 --title "$(__ "Change window title")" --text "$(__ "New window title")"`"
		if [ -z "$NEWTITLE" ]; then
			$NOTIFY_SEND $NOTIFY_SEND_ARGS "$(__ "Title hasn't been changed.")"
			exit
		fi
		$WMCTRL -i -r $3 -N "$NEWTITLE"
		$NOTIFY_SEND $NOTIFY_SEND_ARGS "$(__ "Title changed successfully")"
	fi
}

$NOTIFY_SEND $NOTIFY_SEND_ARGS "$(__ "Please, select a Window to change it's title")"
$WMCTRL -a :SELECT: -v 2>&1 | while read line; do get_window $line; done

