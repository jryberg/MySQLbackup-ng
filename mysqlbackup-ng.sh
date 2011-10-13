#!/bin/sh
#
# Copyright (c) 2011, Johan Ryberg
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#    This product includes software developed by the <organization>.
# 4. Neither the name of the <organization> nor the
#    names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY Johan Ryberg ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# MySQLbackup-ng
# Dumps an MYSQL database to a compressed file and optionaly sends it with scp to a remote server.
# Web: https://github.com/jryberg/MySQLbackup-ng

#  git init
#  touch README
#  git add README
#  git commit -m 'first commit'
#  git remote add origin git@github.com:jryberg/MySQLbackup-ng.git
#  git push -u origin master

appname=`basename $0`
version="2.0"
#
# Set some defaults
# ssh
sshopts=""
identity=""
username=""
password=""

# path and filenames
tempfile=tempfile.$$
dumpfilepath=""
date=`date +%Y%m%d%H%M%S`

# Set absolut path to tools that we need 
verbose=`which false`
mysqldump_path=`which mysqldump`
gzip_path=`which gzip`

# Compression tool
compress_app="gzip"
compress_ext="gz"

#
# Function to do the dump
#
function_do_dump () {
        $verbose && echo "Dumping to ${dumpfile}"

        if [ -z "${database}" ]; then
                if (mysqldump --all-databases -u${username} -p${password} > ${tempfile}); then
			if [ "${compress_ext}" != "" ]; then
				cat ${tempfile} | ${compress_app} > ${dumpfile}
			else
				mv -f ${tempfile} ${dumpfile}	
			fi
			rm -f ${tempfile}
		else
			rm -f ${tempfile}
			exit 1
		fi
        else
                if (mysqldump ${database} -u${username} -p${password} > ${tempfile}); then
                       if [ "${compress_ext}" != "" ]; then
                                cat ${tempfile} | ${compress_app} > ${dumpfile}
                        else
                                mv -f ${tempfile} ${dumpfile}
                        fi
			rm -f ${tempfile}
                else
                        rm -f ${tempfile}
                        exit 1
                fi
        fi

        if [ "$dest" != "" ]; then
                destfile="${dest}${dumpfile}"
                $verbose && echo "Sending dump with scp to ${destfile}"
                if [ "${identity}" = "" ]; then
                        scp ${sshopts} ${dumpfile} ${destfile}
                else
                        scp ${sshopts} -i ${identity} ${dumpfile} ${destfile}
                fi
                rm -f ${dumpfile}
        fi
}


#
# Function to explain how to use the program
#
function_usage () {
	cat - <<EOF 
Usage: ${appname} [--help]
Usage: ${appname} [OPTIONS] [filename] [database [tables]]
Usage: ${appname} [-v] [--scp remote] [--identity ssh-key] [--ssh-opts ssh options] [--out-dir directory name] [--no-compress]

This script dumps a MySQL database and compress it. The filename of each
dump is a base name and the current date.

Using the --scp option the compressed dump file will be moved to a 
remote location using secure copy (ssh).

  --help           -- Show this help
  -V, --version    -- Show version
  -v, --verbose    -- Verbose mode
  --database       -- Database to dump and optional tables (database [tables]). If left empty all databases
                      will be dumped
  --username       -- Database username
  --password       -- Database password
  --filename       -- Base name for dump files, defaults to "dumpfile"
  --scp            -- Location for remote backups.  Files are transfered via scp,
                      then removed from the local directory.
  --identity       -- Identity file for scp transfer
  --ssh-opts       -- Options to use for scp
  --out-dir        -- Path where MySQL dump file should be written
  --no-compress    -- Disables gzip compression

Example:
${appname} -v --scp user@backupserver:/backups/mysql backupfile

EOF
}

#
# Check if required program exists
#
# mysqldump
if ! [ -x "${mysqldump_path}" ]; then
        echo "mysqldump is not found. Aborting!"
        exit 1
fi

# gzip
if ! [ -x "${gzip_path}" ]; then
        echo "gzip is not found. Aborting!"
        exit 1
fi

#
# Process arguments
#
while [ $# -gt 0 ]
do
    opt="$1"
	case "$opt" in
		--help) 
			function_usage
			exit 1 
		;;
		--scp)
			dest="${2}" 
			shift 2
		;;
		--identity)
			identity="${2}"
			shift 2
		;;
		--ssh-opts)  
			sshopts="${2}"
			shift 2
		;;
		--username)
			username="${2}"
			shift 2
		;;
		--password)
			password="${2}"
			shift 2
		;;
		--out-dir) 
			dumpfilepath="${2}"
			shift 2
		;;
		-v|--verbose) 
			verbose=`which true`
			shift 1
		;;
		--no-compress)
			compress_app="" 
		       	compress_ext=""
			shift 1
		;;
		--version|-V)
			echo "${appname} ${version}"
			exit 1
		;;
		-*)
			echo "${appname}: invalid option '${1}'"
                        echo "Try '${appname} --help' for more information."
                        exit 1
		;;
		*)
			dumpfilename=${1}
			if [ $# -gt 0 ]; then 
				shift 1
			fi

			while [ $# -gt 0 ]
			do
				if [ "${database}" = "" ]; then
					database=${1}
				else
					database="$database ${1}"
				fi
				shift 1
			done
		;;
	esac
done

#
# Set dumpfile path and filename
#
if [ "${compress_ext}" = "" ]; then
	dumpfile="${dumpfilepath}${dumpfilename}-${date}"
else
	dumpfile="${dumpfilepath}${dumpfilename}-${date}.${compress_ext}"
fi

if [ "${dumpfilename}" != "" ]; then
        $verbose && echo "	Base file name: ${dumpfilename}"
else
        echo "Base file name missing, aborting!"
        function_usage
        exit 1
fi

if [ "${database}" != "" ]; then
        $verbose && echo "	Database: ${database}"
fi

if [ "${dest}" != "" ]; then
	$verbose && echo "	Destination: ${dest}"
fi

if [ "${identity}" != "" ]; then
	$verbose && echo "	Identity: ${identity}"
fi

if [ "${sshopts}" != "" ] ; then
	$verbose && echo "	SSH options: ${sshopts}"
fi

#
# Do the dump
#

function_do_dump || exit 1

$verbose && echo "Done"
exit 0

