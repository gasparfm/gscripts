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

echo $TEXTDOMAINDIR

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
