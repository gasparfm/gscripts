#!/bin/bash
WMCTRL=`which wmctrl`
ZENITY=`which zenity`
NOTIFY_SEND=`which notify-send`
NOTIFY_SEND_ARGS="-t 2000 -i window-duplicate"
# First implementation. No locales. Spanish for now
function get_window()
{
	if [ "$1" == "Using" ]; then
		WINDOWLIST="`$WMCTRL -l`"
		if [ -z "`echo $WINDOWLIST | grep $3`" ]; then
			$ZENITY --error --text "No se encuentra la ventana seleccionada"
			exit
		fi
		NEWTITLE="`zenity --entry --width 350 --title "Cambiar título de ventana" --text "Nuevo título de la ventana"`"
		if [ -z "$NEWTITLE" ]; then
			$NOTIFY_SEND $NOTIFY_SEND_ARGS "No se ha cambiado el título."
			exit
		fi
		$WMCTRL -i -r $3 -N "$NEWTITLE"
		$NOTIFY_SEND $NOTIFY_SEND_ARGS "El titulo se ha cambiado correctamente"
	fi
}

$NOTIFY_SEND $NOTIFY_SEND_ARGS "Seleccione la ventana para cambiar su nombre"
$WMCTRL -a :SELECT: -v 2>&1 | while read line; do get_window $line; done

