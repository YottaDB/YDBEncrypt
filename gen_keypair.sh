#!/bin/sh
#################################################################
#                                                               #
# Copyright (c) 2010-2021 Fidelity National Information		#
# Services, Inc. and/or its subsidiaries. All rights reserved.	#
#                                                               #
# Copyright (c) 2021-2024 YottaDB LLC and/or its subsidiaries.	#
#								#
#       This source code contains the intellectual property     #
#       of its copyright holder(s), and is made available       #
#       under a license.  If you do not know the terms of       #
#       the license, please stop and do not read further.       #
#                                                               #
#################################################################

#############################################################################################
#
#       gen_keypair.sh - Generates a new public/private key pair for the current user.
#	The email address identifies the user.  It is an error if the gpg keyring exists.
#
#       Arguments:
#               $1 -    Email ID of the current user
#               $2 -    Optional; Any residual text on line is full name of user
#
#############################################################################################

# GnuPG uses $GNUPGHOME, if set, for GNU Privacy Guard keyring
# Script uses $gtm_pubkey, if set for file containing exported ASCII armored public key

hostos=`uname -s`

# temporary file
if [ -x "$(command -v mktemp)" ] ; then tmp_file=`mktemp`
else tmp_file=/tmp/`basename $0`_$$.tmp ; fi
touch $tmp_file
chmod go-rwx $tmp_file
trap 'rm -rf $tmp_file ; if [ -t 0 ]; then stty sane; fi; exit 1' HUP INT QUIT TERM TRAP

# echo and options
ECHO=/bin/echo
ECHO_OPTIONS=""
#Linux honors escape sequence only when run with -e
if [ "Linux" = "$hostos" ] ; then ECHO_OPTIONS="-e" ; fi

# e-mail address is a mandatory parameter for GnuPG and cannot be null.
if [ $# -lt 1 ] ; then
    $ECHO "Usage: `basename $0` email_address [Real name]" ; exit 1
fi
email=$1 ; shift

# Identify GnuPG - it is required
gpg=`command -v gpg2`
if [ -z "$gpg" ] ; then gpg=`command -v gpg` ; fi
if [ -z "$gpg" ] ; then $ECHO "Unable to find gpg2 or gpg. Exiting" ; exit 1 ; fi

# Default file for exported public key, if not specified
if [ -z "$gtm_pubkey" ] ; then gtm_pubkey="${email}_pubkey.txt" ; fi

# If nothing on the command line for the user name, use userid
if [ $# -ge 1 ] ; then gtm_user="$*" ; else gtm_user=$USER ; fi

# If GNUPGHOME is already defined, then use this as the place to store the keys. If undefined,
# use $HOME/.gnupg (default for GnuPG)
if [ -z "$GNUPGHOME" ]; then
        gtm_gpghome="$HOME/.gnupg"
else
        gtm_gpghome="$GNUPGHOME"
fi

if [ -d "$gtm_gpghome" ] || [ -f "$gtm_gpghome" ] ; then
    $ECHO "$gtm_gpghome already exists; cannot create a new directory" ; exit 1
fi
mkdir -p $gtm_gpghome
if [ ! -d $gtm_gpghome ] ; then
    $ECHO "Unable to create directory $gtm_gpghome" ; exit 1
fi
trap 'rm -rf $tmp_file $gtm_gpghome ; if [ -t 0 ]; then stty sane; fi; exit 1' HUP INT QUIT TERM TRAP
chmod go-rwx $gtm_gpghome

# Get passphrase for new GnuPG keyring
unset passphrase
while [ -z "$passphrase" ] ; do
    $ECHO $ECHO_OPTIONS Passphrase for new keyring: \\c
    if [ -t 0 ]; then
        stty -echo
    fi
    read -r passphrase
    if [ -t 0 ]; then
        stty echo
    fi
    $ECHO ""
    $ECHO $ECHO_OPTIONS  Verify passphrase: \\c
    if [ -t 0 ]; then
        stty -echo
    fi
    read -r tmp
    if [ -t 0 ]; then
        stty echo
    fi
    $ECHO ""
    if [ "$passphrase" != "$tmp" ] ; then
        $ECHO Verification does not match passphrase.  Try again. ; unset passphrase
    fi
    unset tmp
done

# Fill out the unattended key generation details including the passphrase and email address
key_info="Key-Type: RSA\n Key-Length: 2048\n Subkey-Type: RSA\n Subkey-Length: 2048\n Name-Real: $gtm_user\n"
key_info=$key_info" Name-Email: $email\n Expire-Date: 0\n Passphrase: $passphrase\n %commit\n %echo Generated\n"

# Run the unattended GnuPG key generation. Any errors will be output to gen_key.log
# which will later be removed.

$ECHO Key ring will be created in $gtm_gpghome
$ECHO Key generation might take some time.  Do something that will create entropy,
$ECHO like moving the mouse or typing in another session.
$ECHO $ECHO_OPTIONS $key_info | $gpg --homedir $gtm_gpghome --no-tty --batch --gen-key 2> $tmp_file

# Set up pinentry-gtm so that GnuPG version 2 pinentry will return password from
# obfuscated password. dir should be an absolute path name.
dir=`dirname $0`
if [ -z "$dir" ] ; then dir=$PWD
else
    case $dir in
	/*) ;;
	.) dir=$PWD ;;
	*) dir=$PWD/$dir ;;
    esac
fi
$ECHO "pinentry-program $dir/pinentry-gtm.sh" >$gtm_gpghome/gpg-agent.conf

if $gpg --homedir $gtm_gpghome --list-keys | grep "$email" >> $tmp_file; then
	$gpg --homedir $gtm_gpghome --export --armor -o $gtm_pubkey
	$gpg --homedir $gtm_gpghome --list-keys --fingerprint
	$ECHO "Key pair created and public key exported in ASCII to $gtm_pubkey"
else
	$ECHO "Error creating public key/private key pairs."
	cat $tmp_file
fi

rm -f $tmp_file
