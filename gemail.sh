#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# gemail.sh  Copyright (C) 2014  Gaspar Fernández <gaspar.fernandez@totaki.com>

# This bash script will help you to use sendmail allowing us to send e-mails from
# the terminal in a friendly way just say destination, subject and body in the command
# arguments. It allows us also to send mail attachments with local files.
#
# I find it interesting when using remotely a server with SSH and I must send a file
# located in it to someone. I wrote this little script to send the file directly to
# the destination.

# Changelog:
# - 20141129: Initial idea of the script and wrote basic functionality
# - 20141206: Code clean up
# - 20141208: Allows us to send many attachments 
# - 20141211: Removed extra \n when no extra headers
# - 20141212: Preview mode and additional sendmail find
# - 20150113: Bug fix (sendmail with no arguments)
# - 20150210: Added SENDMAIL_BASIC_ARGS to call sendmail -t and allow more recipients
# - 20150210: Bug fix separate recipient and non-recipient headers (for some reason some
#             mailers didn't do it right when they are mixed.
# - 20150216: Allow body to be read from stdin

# To do:
#  - Doc and examples !!!

#MAIL_BOUNDARY="m41lb0und4ry"		# We can randomize it later
MAIL_BOUNDARY=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 40`
SENDMAIL_COMMAND=`which sendmail`
# Read recipients from mail (to use CC and so)
SENDMAIL_BASIC_ARGS="-t"
SENDMAIL_COMMAND="";
function showUsage()
{
# We must extend this help to use headers ans so
	echo $1
	echo "Use:"
	echo "  $2 destination subject body [attachment1] [attachment2] ... [attachmentN]"
	echo
	echo "or:"
	echo
	echo "  $2 destination subject [attachment1] [attachment2] ... [attachmentN] < bodyfile"
	echo
	echo "You can also insert some more headers after the attachments:"
	echo "  \"From: me@email.ext\" or \"From: Me <me@myself.ext>\" to specify my email"
	echo "  \"CC: my@email.ext\" or \"CC: My friend <my@friend.ext>\" for carbon copy"
	echo "  \"BCC: my@email.ext\" or \"BCC: My friend <my@friend.ext>\" for blind carbon copy"
	echo "  \"Reply-to: another@email.com\" for a new reply-to address";
	echo "  Another headers accepted: Date, Organization, X-Mailer"
	echo
	echo "You can use the keyword *preview* to print the command to be executed (if you have attached files the output can be large)"
	exit
}

function findSendmail()
{
# Try to find again sendmail in extra paths not in $PATH
    EXTRAPATHS=("/usr/sbin/" "/sbin/" "/usr/local/sbin/")

    for p in "${EXTRAPATHS[@]}";
    do
	if [ -x "${p}sendmail" ]
	then
	    echo "${p}sendmail"
	    return
	fi 
    done
}

function callsend()
{
    _TO=$1
    _PREVIEW=$2

    if (( $_PREVIEW==1 ))
    then
	cat
    else
	$SENDMAIL_COMMAND $SENDMAIL_BASIC_ARGS $_TO
    fi
}

# Required arguments (destination, subject, body)
NUMARGS=3;

#Basic arguments of our program
TO=$1
SUBJECT=$2
BODY=$3

# If we have data in /dev/stdin pick up the email body from /dev/stdin
if [ ! -t 0 ]
then
    BODY=$(cat /dev/stdin)
    NUMARGS=2;
fi

PREVIEW=0

# Additional sendmail find if not in PATH
if [ -z "$SENDMAIL_COMMAND" ];
then
    SENDMAIL_COMMAND=`findSendmail`
fi

if [ -z "$SENDMAIL_COMMAND" ];
then
    echo "No sendmail found in your PATH. Make sure you have it!"
    exit;
fi

if (( $# < $NUMARGS ))
then
	showUsage "Invalid arguments" $0
fi

# Fill attachments and additional user headers
ATTACHMENTS=""
MOREHEADERS=""
RECIPIENTS=""
for (( i=$(($NUMARGS+1)); $i<=$#; i++))
do
	ATTACH="${!i}"
	if [ ! -r "$ATTACH" ];
	then
 	    # Not an attachment, ok but it can be an additional header it will have : let's check it
	    OLDIFS=$IFS
	    IFS=":"
	    read -a HEADER <<< "$ATTACH"
	    IFS=$OLDIFS
	    case ${HEADER[0]} in
		# Separating headers for some mail systems
		"From" | "Reply-to" | "CC" | "BCC" )
		    if [ -z "$RECIPIENTS" ]
		    then
			RECIPIENTS=$ATTACH
		    else
			RECIPIENTS="`echo -e "$RECIPIENTS""\n""$ATTACH"`"
		    fi 
		    ;;
		"Date" | "X-Mailer" | "Organization" )
		    if [ -z "$MOREHEADERS" ]
		    then
			MOREHEADERS=$ATTACH
		    else
			MOREHEADERS="`echo -e "$MOREHEADERS""\n""$ATTACH"`"
		    fi 
		    ;;
		"preview")
		    PREVIEW=1
		    ;;
		*)
		    showUsage "Attachment not found" $0
	    esac
	else
	    ATTACH_MIME=`file --mime-type -b "$ATTACH"`
	    ATTACH_NAME=`basename "$ATTACH"`
	    ATTACH_BASE64=`base64 "$ATTACH"`
	    ATTACHMENTS="$ATTACHMENTS
--$MAIL_BOUNDARY
Content-Type: $ATTACH_MIME; name=\"$ATTACH_NAME\"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"$ATTACH_NAME\"

$ATTACH_BASE64"
	fi
done

# Send message
( echo "To: $TO";
  if [ -n "$RECIPIENTS" ]; then
      echo -e "$RECIPIENTS"
  fi
  echo "Subject: $SUBJECT";
  if [ -n "$MOREHEADERS" ]; then
      echo -e "$MOREHEADERS"
  fi
  echo "MIME-Version: 1.0";
  echo "Content-Type: multipart/mixed; boundary=\"$MAIL_BOUNDARY\"";
  echo "--"$MAIL_BOUNDARY;
  echo "Content-Type: text/plain";
  echo -e "Content-Disposition: inline\n";
  echo "$BODY";
  echo -e "$ATTACHMENTS"
  echo "--"$MAIL_BOUNDARY"--") | callsend $TO $PREVIEW

RESULT=$?
if (( $RESULT==0 ))
then
    echo "Message sent successfully";
else
    echo "Could not send message"
fi
