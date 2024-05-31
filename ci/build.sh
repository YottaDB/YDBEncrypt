#!/usr/bin/env bash

#################################################################
#								#
# Copyright (c) 2020-2024 YottaDB LLC and/or its subsidiaries.	#
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
# `sort` has different output depending on the locale
export LC_ALL=C

# export $ydb_dist if not exist
set +u
if [ -z "${ydb_dist}" ]; then	
	export ydb_dist="/opt/yottadb/current/"
fi
set -u

mkdir -p warnings
# Record the warnings, but if `make` fails, say why instead of silently exiting.
echo "# Randomly choose to build Debug or Release build"

# In order to use `clang-tidy` we need the `compile_commands.json` file.
# For projects that use `cmake`, running `cmake -D CMAKE_EXPORT_COMPILE_COMMANDS=ON ..` creates this file.
# But YDBEncrypt uses `make` (not cmake) and so we need to use `bear` to generate the json file.
# Although bear did generate the json file like we want, it also issued errors
# (see https://gitlab.com/YottaDB/Util/YDBEncrypt/-/merge_requests/31#note_1936255855 for more details).
# So we suppress the errors with a `set +e` below. 
set +e
if [[ $(( RANDOM % 2)) -eq 0 ]]; then
	build_type="Debug"
	bear -- make image=DEBUG 2>warnings/make_warnings.txt
	status=$?
else
	build_type="Release"
	bear -- make image= 2>warnings/make_warnings.txt
	status=$?
fi
set -e
echo " -> build_type = $build_type"

cp compile_commands.json ci/.

cd warnings || exit
if ! [ $status = 0 ]; then
	echo "# make failed with exit status [$status]. make output follows below"
	cat make_warnings.txt
	exit $status
fi

# There should be no compilation warnings/errors here
if [ -s warnings/make_warning.txt ]; then
	echo "# Compilation error/warning detected. Error/Warning message(s) shown below:"
	cat make_warnings.txt
	exit $status
fi


# This is used for both `make` and `clang-tidy` warnings.
# It should be run from the warnings/ directory.
compare() {
	expected="$1"
	actual="$2"
	original_warnings="$3"
	if [ -e "$expected" ]; then
		# We do not want any failures in "diff" command below to exit the script (we want to see the actual diff a few steps later).
		# So never count this step as failing even if the output does not match.
		# NOTE: ignores trailing spaces, because clang-tidy outputs extra spaces but `sort_warnings.sh` strips them.
		echo "# Running command : diff -Z $expected $actual >& warnings/differences.txt"
		diff -Z "$expected" "$actual" &> warnings/differences.txt || true

		if [ $(wc -l warnings/differences.txt | awk '{print $1}') -gt 0 ]; then
			{
				echo " -> Expected warnings differ from actual warnings! diff output follows"
				echo " -> note: '<' indicates an expected warning, '>' indicates an actual warning"
				cat warnings/differences.txt
				echo
				grep -Ev '^(Database file |%YDB-I-DBFILECREATED, |%GDE-I-|YDB-MUMPS\[)' $original_warnings \
					| grep -v '\.gld$' > $original_warnings.stripped || true;
				echo " -> note: the original warnings are available in $original_warnings.stripped"
				echo " -> note: the expected warnings are available in $expected"
				if [ $build_type = Debug ]; then
					other_job=Release
				else
					other_job=Debug
				fi
				echo " -> warning: since the $build_type job failed, the $other_job job will likely also fail. Make sure you update the relevant warnings for both."
			} > warnings/summary.txt
			cat warnings/summary.txt
			exit 1
		fi
	else
		# Make sure that there are actually no warnings, not just that someone forgot to add a .ref file
		[ $(wc -c < "$actual") = 0 ]
	fi
}
cd ..
ci/create_tidy_warnings.sh warnings .

# NOTE: If this command fails, you can download `sorted_warnings.txt` to `ci/tidy_warnings_debug.ref`
if [ $build_type = Debug ]; then
	compare ci/tidy_warnings_debug.ref warnings/{sorted_warnings.txt,tidy_warnings.txt}
else
	compare ci/tidy_warnings_release.ref warnings/{sorted_warnings.txt,tidy_warnings.txt}
fi

