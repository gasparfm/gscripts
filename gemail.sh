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
# arguments. It allows us also to send mail attachments with local files and allows you
# to use internal sendmail application or connection to a SMTP server.
#
# I find it interesting when using remotely a server with SSH and I must send a file
# located in it to someone. I wrote this little script to send the file directly to
# the destination.

# Changelog:
# - 20160901: Fix selecting SMTP user
#             Fix when sending mails through cron jobs (again) this time,
#             when sending from scripts ran in cron jobs. /dev/stdin is
#             present in some conditions but with no data.
# - 20160706: Several new CLI options.
# - 20160705: Added SMTP support with tiny python script
# - 20160703: Fixes adding headers and autoheaders
# - 20160415: Fix sending mails through cron job. Must check permissions over /dev/stdin
# - 20150216: Allow body to be read from stdin
# - 20150210: Bug fix separate recipient and non-recipient headers (for some reason some
#             mailers didn't do it right when they are mixed.
# - 20150210: Added SENDMAIL_BASIC_ARGS to call sendmail -t and allow more recipients
# - 20150113: Bug fix (sendmail with no arguments)
# - 20141212: Preview mode and additional sendmail find
# - 20141211: Removed extra \n when no extra headers
# - 20141208: Allows us to send many attachments 
# - 20141206: Code clean up
# - 20141129: Initial idea of the script and wrote basic functionality

# To do:
#  - Doc and examples !!!

VERSION="0.8"
#MAIL_BOUNDARY="m41lb0und4ry"		# We can randomize it later
MAIL_BOUNDARY=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 40`
SENDMAIL_COMMAND=`which sendmail`
# Read recipients from mail (to use CC and so)
SENDMAIL_BASIC_ARGS="-t"
SENDMAIL_COMMAND="";
SMTP_DEFAULT_SECURITY="starttls"
_MYNAME=$0

function showUsage()
{
	# We must extend this help to use headers and so
	if [ -n "$1" ]
	then
		echo "Sorry: $1"
		echo
	fi
	echo "gemail.sh Version $VERSION"
	echo "Sends e-mails from terminal the easy way. (https://github.com/gasparfm/gscripts)"
	echo
	echo "Use:"
	echo "  $_MYNAME [options] [destination] [subject] [body] [attachment1] [attachment2] ... [attachmentN]"
	echo
	echo "or:"
	echo
	echo "  $_MYNAME [options] [destination] [subject] [attachment1] [attachment2] ... [attachmentN] < bodyfile"
	echo
	echo "These are the supported options:"
	echo " -t, --to=destination 	: Adds to recipient to the e-mail (if this option is"
	echo "				  present you can dismiss [destination] argument)."
	echo " -f, --from=origin	: This is YOUR e-mail."
	echo " -s, --subject=subject	: The subject of your message. (if this option is "
	echo "				  present you can dismiss [subject] argument)."
	echo " -b, --body=message	: This is yout message. (if this option is present,"
	echo "				  you can dismiss [body] argument)."
	echo " -p, --preview		: Don't send the message, just preview the e-mail."
	echo " -h, --header=content	: Adds new header to the e-mail. Allowed headers are:"
	echo "				  From, CC, BCC, Reply-to, Date, Organization, "
	echo "				  X-Mailer and Message-Id."
	echo " -a, --attach=file	: Attaches this file to the e-mail."
	echo " -e, --smtp=conn_str	: Gives SMTP server or connection string."
	echo "			  This connection string can be: "
	echo " 			    * server hostname or IP"
	echo "			    * user:password@server (if user or password has :"
	echo "			       or @ characters they may be escaped.)"
	echo " -u, --smtp-user=user	: Sets SMTP server user."
	echo " -w, --smtp-pass=passwd	: Sets SMTP server password."
	echo " -n, --noautoheaders	: Disables gemail.sh automatic headers."
	echo
	echo "You can also insert some more headers after the attachments:"
	echo "  \"From: me@email.ext\" or \"From: Me <me@myself.ext>\" to specify my email"
	echo "  \"CC: my@email.ext\" or \"CC: My friend <my@friend.ext>\" for carbon copy"
	echo "  \"BCC: my@email.ext\" or \"BCC: My friend <my@friend.ext>\" for blind carbon copy"
	echo "  \"Reply-to: another@email.com\" for a new reply-to address";
	echo "  Another headers accepted: Date, Organization, X-Mailer, Message-Id"
	echo
	echo "You can use the keyword *preview* to print the command to be executed (if you have attached files the output can be large)"
	exit
}

function findSendmail()
{
	# Try to find again sendmail in extra paths not in $PATH
	EXTRAPATHS=("/usr/sbin/" "/sbin/" "/usr/local/sbin/" "$HOME/.local/bin/")

	for p in "${EXTRAPATHS[@]}";
	do
		if [ -x "${p}sendmail" ]
		then
			echo "${p}sendmail"
			return
		fi 
	done
}

function test_py()
{
	if [ -z "$(which python)" ]
	then
		echo "Python not found"
		return;
	fi

	python <<EOF
try:
import smtplib
except ImportError as er:
print er
EOF
}

function pysmtp()
{
	TO="$1"
	while read line
	do
		echo "$line"
	done | python <(cat <<EOF
import smtplib
import sys
try:
 smtpObj = smtplib.SMTP('$SMTP_SERVER')
 if ('$SMTP_SECURITY' == 'starttls'):
   smtpObj.starttls()
 if ('$SMTP_USER'):
   smtpObj.login('$SMTP_USER', '$SMTP_PASS')
 message = sys.stdin.read()
 _from = message.find('From:')
 fromstr = 'root'
 if _from != -1:
   fromstr = message[_from+5:message.find('\n', _from)]
 smtpObj.sendmail(fromstr.strip(), '$_TO', message)
except Exception as e:
 print e
EOF
	)
}

function callsend()
{
	_TO="$1"
	_PREVIEW=$2
	if (( $_PREVIEW==1 ))
	then
		cat
	elif [ $SENDER = "sendmail" ]
	then
		if [ -z "$SENDMAIL_COMMAND" ];
		then
			echo "No sendmail found in your PATH. Make sure you have it!"
			exit 1;
		fi
		$SENDMAIL_COMMAND $SENDMAIL_BASIC_ARGS "$_TO"
	elif [ $SENDER = "smtp" ]
	then
		PYERR="$(test_py)"
		if [ -n "$PYERR" ]
		then
			echo "Python error: $PYERR"
			exit 1;
		fi
		RESPONSE="$(pysmtp "$TO")"
		if [ -n "$RESPONSE" ]
		then
			echo "Error sending via SMTP: $RESPONSE"
			return 1;
		fi
	fi
}

function add_attachment()
{
	ATTACH="$1"
	ATTACH_MIME=`file --mime-type -b "$ATTACH"`
	ATTACH_NAME=`basename "$ATTACH"`
	ATTACH_BASE64=`base64 "$ATTACH"`
	ATTACHMENTS="$ATTACHMENTS
--$MAIL_BOUNDARY
Content-Type: $ATTACH_MIME; name=\"$ATTACH_NAME\"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"$ATTACH_NAME\"

$ATTACH_BASE64"
}

function add_header()
{
	HEADERINFO="$1"
	OLDIFS=$IFS
	IFS=":"
	read -a HEADER <<< "$HEADERINFO"
	IFS=$OLDIFS
	case ${HEADER[0]} in
		# Separating headers for some mail systems
		"From" | "Reply-to" | "CC" | "BCC" )
			if [ "${HEADER[0]}" = "From" ] || [ "${HEADER[0]}" = "Reply-to" ]
			then
				RECIPIENTS="$(echo -e "$RECIPIENTS" | grep -v "${HEADER[0]}:")"
			fi

			if [ -z "$RECIPIENTS" ]
			then
				RECIPIENTS=$HEADERINFO
			else
				RECIPIENTS="`echo -e "$RECIPIENTS""\n""$HEADERINFO"`"
			fi 
			;;
		"Date" | "X-Mailer" | "Organization" | "Message-Id" )
			MOREHEADERS="$(echo -e "$MOREHEADERS" | grep -v "${HEADER[0]}:")"
			if [ -z "$MOREHEADERS" ]
			then
				MOREHEADERS=$HEADERINFO
			else
				MOREHEADERS="`echo -e "$MOREHEADERS""\n""$HEADERINFO"`"
			fi 
			;;
		"preview")
			PREVIEW=1
			;;
		*)
			showUsage "Attachment $HEADERINFO not found"
	esac
}

function add_auto_headers()
{
	if [ "$AUTOHEADERS" = "yes" ]
	then
		if [ -z "$(grep "From:" <<< $RECIPIENTS)" ]
		then
			add_header "From: $(echo `whoami`@`hostname`)"
		fi

		if [ -z "$(grep "Date: " <<< $MOREHEADERS)" ]
		then
			add_header "Date: $(date -R) ($(date +%Z))"
		fi

		if [ -z "$(grep "Message-Id: " <<< $MOREHEADERS)" ]
		then
			_FROM=$(grep "From:" <<< $RECIPIENTS)
			add_header "Message-Id: <"$(uuidgen | awk -F'-' -v date=$(date +%Y%m%d%H%M%S) -v at=$(echo $_FROM | cut -d'@' -f2) '{print $1$2"."date"."$3$4"@"at}')">"
		fi
		if [ -z "$(grep "X-Mailer: " <<< $MOREHEADERS)" ]
		then
			add_header "X-Mailer: gemail.sh Ver. $VERSION"
		fi
	fi
}

function smtp_settings()
{
	STS="$1"

	OLDIFS=$IFS
	IFS=$(echo -e "\n")
	while read user
	do
		read pass
		read server
		break
	done <<< $(sed -r 's/([^\:\@]*(\\:[^\:\@]*)*):([^\@]*(\\@[^\:\@]*)*)@([^\/\:]*)/\1\n\3\n\5/' <<< "$STS");
	if [ -z "$user" ]
	then
		showUsage "Wrong SMTP server string: \"$STS\""
	fi
	SENDER="smtp"
	if [ -z "$pass" ] && [ -z "$server" ]
	then
		# We only have server
		SMTP_SERVER="$user"
	else
		SMTP_SERVER="$server"
		SMTP_USER="$user"
		SMTP_PASS="$pass"
	fi
	SMTP_SECURITY=$SMTP_DEFAULT_SECURITY
}

# Fill missing headers automatically
AUTOHEADERS="yes"
ATTACHMENTS=""
MOREHEADERS=""
RECIPIENTS=""

# By default, no PREVIEW
PREVIEW=0

# By default, sent by sendmail
SENDER="sendmail"

# Parse input arguments
ARGS=$(getopt -q -o "t:f:s:b:ph:a:e:u:w:n" -l "to:,from:,subject:,body:,preview,header:,attach:,smtp:,smtp-user:,smtp-pass:,noautoheaders" -n "gemail.sh" -- "$@");
if [ $? -ne 0 ];
then
	showUsage "Error parsing arguments"
fi

eval set -- "$ARGS";

while [ $# -gt 0 ]; do
	case "$1" in
		-t|--to)
			TO="$2"
			shift;
			;;
		-f|--from)
			add_header "From: $2"
			shift;
			;;
		-s|--subject)
			SUBJECT="$2"
			shift;
			;;
		-b|--body)
			BODY="$3"
			shift;
			;;
		-p|--preview)
			PREVIEW=1
			;;
		-h|--header)
			add_header "$2"
			shift;
			;;
		-a|--attach)
			add_attachment "$2"
			shift;
			;;
		-e|--smtp)
			smtp_settings "$2"
			shift;
			;;
		-u|--smtp-user)
			SMTP_USER="$2"
			shift
			;;
		-w|--smtp-pass)
			SMTP_PASS="$2"
			shift
			;;

		-n|--noautoheaders)
			AUTOHEADERS="no"
			;;
		--)
			shift;
			break;
			;;
		*)
			echo "Unrecognised option \"$1\""
			showUsage
	esac
	shift;
done
if [ -n "$1" ] && [ -z "$TO" ]
then
	TO="$1"
	shift
fi

if [ -n "$1" ] && [ -z "$SUBJECT" ]
then
	SUBJECT="$1"
	shift
fi

# If we have data in /dev/stdin pick up the email body from /dev/stdin
# -t 0 : make sure stdin (fd=0) is not a terminal as this program is not
# interactive
if [ -r /dev/stdin ] && [ ! -t 0 ]
then
	BODY=$(cat /dev/stdin)
fi
# If we have no body yet, test the argument. In cron jobs /dev/stdin may
# be detected with no data.
if [ -n "$1" ] && [ -z "$BODY" ]
then
	BODY="$1"
	shift
fi

# Additional sendmail find if not in PATH
if [ -z "$SENDMAIL_COMMAND" ];
then
	SENDMAIL_COMMAND=`findSendmail`
fi

# Fill attachments and additional user headers
while [ $# -gt 0 ]
do
	ATTACH="$1"
	if [ ! -r "$ATTACH" ];
	then
 		# Not an attachment, ok but it can be an additional header it will have : let's check it
		add_header "$ATTACH"
	else
		add_attachment "$ATTACH"
	fi
	shift
done

if [ -z "$TO" ]
then
	showUsage "No recipient found."
elif [ -z "$SUBJECT" ]
then
	showUsage "No subject found."
elif [ -z "$BODY" ]
then
	showUsage "No body found."
fi

# echo "TO: $TO"
# echo "SUBJECT: $SUBJECT"
# echo "BODY: $BODY"

add_auto_headers

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
	echo -e "\n"
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
