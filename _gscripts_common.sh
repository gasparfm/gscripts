#!/bin/bash
GETTEXT=`which gettext`
DOMAIN="gscripts"

# Possible locale paths:
#   * /usr/share/locale (gettext default)
#   * $SCRIPT_SOURCE/locale
#   * $SCRIPT_SOURCE/gscripts/locale
if [ -z "`ls -R /usr/share/locale | grep $DOMAIN.mo`" ]; then
    if [ -n "`ls -R $SCRIPT_SOURCE/gscripts/locale | grep $DOMAIN.mo`" ]; then
	TEXTDOMAINDIR=$SCRIPT_SOURCE/gscripts/locale
    else
	TEXTDOMAINDIR=$SCRIPT_SOURCE/locale
    fi
fi

#echo $TEXTDOMAINDIR

function __()
{
    ARGS=$@

    if [ -z "$GETTEXT" ]; then
	printf "$ARGS"
    else
	LINE="$1"
	shift
	printf "$(gettext "$DOMAIN" "$LINE")" $@
    fi
}

function load_gscripts_config()
{
    # Search order:
    # $HOME/.config/gscripts/gscripts.conf
    # $HOME/.gscripts.conf
    # $HOME/.gscripts/gscripts.conf
    # /usr/local/share/gscripts/gscripts.default.conf
    # /usr/share/gscripts/gscripts.default.conf
    # $SCRIPT_SOURCE/gscripts.default.conf
    HOME="`echo ~`"
    if [ -r "$HOME/.config/gscripts/gscripts.conf" ]
    then
	. "$HOME/.config/gscripts/gscripts.conf"
    elif [ -r "$HOME/.gscripts.conf" ]
    then
	. "$HOME/.gscripts.conf"
    elif [ -r "$HOME/.gscripts/gscripts.conf" ]
    then
	. "$HOME/.gscripts/gscripts.conf"
    elif [ -r "/usr/local/share/gscripts/gscripts.default.conf" ]
    then
	. "/usr/local/share/gscripts/gscripts.default.conf"
    elif [ -r "/usr/share/gscripts/gscripts.default.conf" ]
    then
	. "/usr/share/gscripts/gscripts.default.conf"
    elif [ -r "$SCRIPT_SOURCE/gscripts.default.conf" ]
    then
	. "$SCRIPT_SOURCE/gscripts.default.conf"
    else
	echo "Config file not found!"
	exit -3
    fi
}
