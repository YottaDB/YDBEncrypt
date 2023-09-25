#!/bin/sh
#################################################################
#                                                               #
# Copyright (c) 2010-2021 Fidelity National Information		#
# Services, Inc. and/or its subsidiaries. All rights reserved.	#
#                                                               #
# Copyright (c) 2021-2023 YottaDB LLC and/or its subsidiaries.	#
#								#
#       This source code contains the intellectual property     #
#       of its copyright holder(s), and is made available       #
#       under a license.  If you do not know the terms of       #
#       the license, please stop and do not read further.       #
#                                                               #
#################################################################

#############################################################################################
#
#       import_and sign_key.sh: Import public key into the owner's keyring. After confirming
#	the fingerprint, sign the key.
#
#	Arguments -
#	$1 - path of the public key file.
#	$2 - email id of the public key's owner.
#
#############################################################################################

hostos=`uname -s`

# echo and options
ECHO=/bin/echo
ECHO_OPTIONS=""
#Linux honors escape sequence only when run with -e
if [ "Linux" = "$hostos" ] ; then ECHO_OPTIONS="-e" ; fi

# Path to key file and email id are required
if [ $# -lt 2 ]; then
    $ECHO  "Usage: `basename $0` public_key_file email_id"
    exit 1
fi
public_key_file=$1
email_id=$2

# Identify GnuPG - it is required
gpg=`command -v gpg2`
if [ -z "$gpg" ] ; then gpg=`command -v gpg` ; fi
if [ -z "$gpg" ] ; then $ECHO "Unable to find gpg2 or gpg. Exiting" ; exit 1 ; fi

# Exit if the public key for this id already exists in the keyring
if $gpg --list-keys $email_id 2>/dev/null 1>/dev/null; then
    $ECHO  "Public key of $email_id already exists in keyring."
fi

# Ensure that the public key file exists and is readable
if [ ! -r $public_key_file ] ; then
    $ECHO  "Key file $public_key_file not accessible." ; exit 1
fi

# Import the public key into the keyring
if ! $gpg --no-tty --import --yes $public_key_file; then
    $ECHO  "Error importing public key for $email_id from $public_key_file" ; exit 1
fi

# Display fingerprint of the just imported public key
$ECHO  "#########################################################"
if ! $gpg --fingerprint $email_id; then
    $ECHO  "Error obtaining fingerprint the email id - $email_id" ; exit 1
fi
$ECHO  "#########################################################"

trap 'stty sane ; exit 1' HUP INT QUIT TERM TRAP

# Confirm with the user whether the fingerprint matches
unset tmp
while [ "Y" != "$tmp" ] ; do
    $ECHO $ECHO_OPTIONS "Please confirm validity of the fingerprint above (y/n/[?]):" \\c
    read -r tmp ; tmp=`$ECHO $tmp | tr yesno YESNO`
    case $tmp in
	"Y"|"YE"|"YES") tmp="Y" ;;
	"N"|"NO") $ECHO Finger print of public key for $email_id in $public_key_file not confirmed
	    $gpg --no-tty --batch --delete-keys --yes $email_id
	    exit 1 ;;
	*) $ECHO
	    $ECHO "If the fingerprint shown above matches the fingerprint you have been indepently"
	    $ECHO "provided for the public key of this $email_id, then press Y otherwise press N"
	    $ECHO ;;
    esac
done
unset tmp


#If yes, we need to sign the public key. In order to do so, we need the user's passphrase.
# Get passphrase for GnuPG keyring
$ECHO $ECHO_OPTIONS Passphrase for keyring: \\c ; stty -echo ; read -r passphrase ; stty echo ; $ECHO ""

# Export and sign the key
if $ECHO  $passphrase | $gpg --no-tty --batch --passphrase-fd 0 --sign-key --yes $email_id; then
    $ECHO  "Successfully signed public key for $email_id received in $public_key_file" ; exit 0
else
    $gpg --no-tty --batch --delete-keys --yes $email_id
    $ECHO  "Failure signing public key for $email_id received in $public_key_file" ; exit 1
fi
