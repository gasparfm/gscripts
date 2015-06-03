#!/bin/bash
WMCTRL=`which wmctrl`
ZENITY=`which zenity`
# Leave this variable as is. zenity will use it to keep 
# associated to a Window and we don't want this
WINDOWID=
NOTIFY_SEND=`which notify-send`
NOTIFY_SEND_ARGS="-t 2000 -i window-duplicate"
# First implementation. No locales. Spanish for now

function already_stopped()
{
    WINPID=$1
    NAME="$2"

    $ZENITY --question --text "El proceso $2 está pausado. ¿Desea reanudarlo?" --title "Proceso pausado"
    RES=$?
    if [ "$RES" == "0" ]; then
	kill -SIGCONT $WINPID
	RES=$?
	if [ "$RES" == "0" ]; then
	    $NOTIFY_SEND $NOTIFY_SEND_ARGS "Se ha reanudado el proceso $NAME"
	fi
    fi
}

function already_running()
{
    WINPID=$1
    NAME="$2"
    PCPU=`ps ax -o pid,pcpu | grep $WINPID | awk '{print $2}'`
    $ZENITY --question --text "El proceso $2 está corriendo y consumiendo "$PCPU"% de CPU. ¿Desea pausarlo?" --title "Proceso en curso"
    RES=$?
    if [ "$RES" == "0" ]; then
	kill -SIGSTOP $WINPID
	RES=$?
	if [ "$RES" == "0" ]; then
	    $NOTIFY_SEND $NOTIFY_SEND_ARGS "Se ha pausado el proceso $NAME"
	fi
    fi
}

function state_changer()
{
    WINPID=$1
    STATUS=`cat /proc/$WINPID/status`
    NAME=`echo "$STATUS" | grep "Name:" | awk '{print $2}'`
    STATE=`echo "$STATUS" | grep "State:" | awk '{print $2}'`

    if [ "$STATE" == "T" ]; then
	already_stopped $WINPID "$NAME"
    else
	already_running $WINPID "$NAME"
    fi
}

function get_window()
{
	if [ "$1" == "Using" ]; then
		WINDOWLIST="`$WMCTRL -l -p | grep $3`"
		if [ -z "$WINDOWLIST" ]; then
			$ZENITY --error --text "No se encuentra la ventana seleccionada"
			exit
		fi
		WINPID=`echo "$WINDOWLIST" | awk '{print $3}'`
		state_changer $WINPID
	fi
}

$NOTIFY_SEND $NOTIFY_SEND_ARGS "Seleccione la ventana para ver el estado del proceso"
$WMCTRL -a :SELECT: -v 2>&1 | while read line; do get_window $line; done

