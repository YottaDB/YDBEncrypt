#!/usr/bin/env bash

#################################################################
#								#
# Copyright (c) 2022 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

# Exit on error; disallow unset variables; print each command as it is executed
set -euv
# If any command in a pipeline fails, count the entire pipeline as failed
set -o pipefail

# Clone the YDB repo. It will be in a subdirectory called YDB.
git clone https://gitlab.com/YottaDB/DB/YDB.git

status=0

# Check to make sure none of the files moved to YDBEncrypt still exist in YDB
movedlist="sr_unix/Makefile.mk sr_unix/encrypt_sign_db_key.sh sr_unix/gen_keypair.sh sr_unix/gen_sym_hash.sh"
movedlist="$movedlist sr_unix/gen_sym_key.sh sr_unix/gtm_tls_impl.c sr_unix/gtm_tls_impl.h sr_unix/gtmcrypt_dbk_ref.c"
movedlist="$movedlist sr_unix/gtmcrypt_dbk_ref.h sr_unix/gtmcrypt_pk_ref.c sr_unix/gtmcrypt_pk_ref.h"
movedlist="$movedlist sr_unix/gtmcrypt_ref.c sr_unix/gtmcrypt_ref.h sr_unix/gtmcrypt_sym_ref.c sr_unix/gtmcrypt_sym_ref.h"
movedlist="$movedlist sr_unix/gtmcrypt_util.c sr_unix/gtmcrypt_util.h sr_unix/import_and_sign_key.sh sr_unix/maskpass.c"
movedlist="$movedlist sr_unix/pinentry-gtm.sh sr_unix/pinentry.m sr_unix/show_install_config.sh"

# Disable exit on error because we might see errors below while checking for previously moved files
# that still exist in the YDB repo.
for file in $movedlist ; do
	if [ -f YDB/$file ] ; then
		echo "$file found in YDB repo. This file was previously moved to the YDBEncrypt repo and should not exist in YDB."
		status=1
	fi
done

# Run diffs on all files that have copies in both YDB and YDBEncrypt repos expecting no output
enclist="sr_port/minimal_gbldefs.c sr_port/ydb_getenv.c sr_port/ydb_getenv.h sr_port/ydb_logicals.h"
enclist="$enclist sr_port/ydb_logicals_tab.h sr_unix/ydb_tls_interface.h sr_unix/ydbcrypt_interface.h"

# Get list of files changed in an MR so this pipeline will pass for MRs even if they're different from master in YDB repo
# below is adapted from the commit_verify.sh pipeline script
upstream_repo="https://gitlab.com/YottaDB/Util/YDBEncrypt.git"
# Add $upstream_repo as remote
if ! git remote | grep -q upstream_repo; then
	git remote add upstream_repo "$upstream_repo"
	git fetch upstream_repo
else
	echo "Unable to add $upstream_repo as remote, remote name upstream_repo already exists"
	exit 1
fi
target_branch="master"
# Fetch all commit ids only present in MR by comparing to master branch"
commit_list=`git rev-list upstream_repo/$target_branch..HEAD`
filelist="$(git show --pretty="" --name-only $commit_list | sort -u)"

# Disable exit on error because we might see errors below while checking for differences
# between files in YDB and YDBEncrypt repos
for ydbfile in $enclist ; do
	encfile=${ydbfile##*/}	# Extracts the file name minus the directory path. We need this because all files are
				# in the root directory of the YDBEncrypt repo but are split between the sr_unix and
				# sr_port directories of the YDB repo.
	set +e
	diff $encfile YDB/$ydbfile > diff.out
	set -e
	if [ -s diff.out ] ; then
		echo "The contents of $ydbfile are different in the YDB and YDBEncrypt repos"
		cat diff.out
		if [ 0 == $status ] ; then
			status=1
			for file in $filelist ; do
				if [ $file == $encfile ] ; then
					status=0
				fi
			done
		fi
	fi
done

exit $status
