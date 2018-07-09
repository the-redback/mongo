#!/bin/bash
set -Eexuo pipefail

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 1"

if [ "${1:0:1}" = '-' ]; then
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 2"
	set -- mongod "$@"
fi

originalArgOne="$1"

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 3"
# allow the container to be started with `--user`
# all mongo* commands should be dropped to the correct user
if [[ "$originalArgOne" == mongo* ]] && [ "$(id -u)" = '0' ]; then
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 4"
	if [ "$originalArgOne" = 'mongod' ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 5"
		chown -R mongodb /data/configdb /data/db
	fi

	# make sure we can write to stdout and stderr as "mongodb"
	# (for our "initdb" code later; see "--logpath" below)
	chown --dereference mongodb "/proc/$$/fd/1" "/proc/$$/fd/2" || :
	# ignore errors thanks to https://github.com/docker-library/mongo/issues/149

	exec gosu mongodb "$BASH_SOURCE" "$@"
fi
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 6"
# you should use numactl to start your mongod instances, including the config servers, mongos instances, and any clients.
# https://docs.mongodb.com/manual/administration/production-notes/#configuring-numa-on-linux
if [[ "$originalArgOne" == mongo* ]]; then
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 7"
	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 8"
		set -- $numa "$@"
	fi
fi
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 9"
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 10"
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 11"
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 12"
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 13"
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 14"
# see https://github.com/docker-library/mongo/issues/147 (mongod is picky about duplicated arguments)
_mongod_hack_have_arg() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 15"
	local checkArg="$1"; shift
	local arg
	for arg; do
		case "$arg" in
			"$checkArg"|"$checkArg"=*)
			    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 16"
				return 0
				;;
		esac
	done
	return 1
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 17"
# _mongod_hack_get_arg_val '--some-arg' "$@"
_mongod_hack_get_arg_val() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 18"
	local checkArg="$1"; shift
	while [ "$#" -gt 0 ]; do
	    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 19"
		local arg="$1"; shift
		case "$arg" in
			"$checkArg")
			    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 20"
				echo "$1"
				return 0
				;;
			"$checkArg"=*)
			    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 21"
				echo "${arg#$checkArg=}"
				return 0
				;;
		esac
	done
	return 1
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 22"
declare -a mongodHackedArgs
# _mongod_hack_ensure_arg '--some-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 23"
	local ensureArg="$1"; shift
	mongodHackedArgs=( "$@" )
	if ! _mongod_hack_have_arg "$ensureArg" "$@"; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 24"
		mongodHackedArgs+=( "$ensureArg" )
	fi
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 25"
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 26"
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
	    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 27"
		local arg="$1"; shift
		if [ "$arg" = "$ensureNoArg" ]; then
		    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 28"
			continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 29"
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg_val() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 30"
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
	    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 31"
		local arg="$1"; shift
		case "$arg" in
			"$ensureNoArg")
			    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 32"
				shift # also skip the value
				continue
				;;
			"$ensureNoArg"=*)
			    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 33"
				# value is already included
				continue
				;;
		esac
		mongodHackedArgs+=( "$arg" )
	done
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 34"
# _mongod_hack_ensure_arg_val '--some-arg' 'some-val' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg_val() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 35"
	local ensureArg="$1"; shift
	local ensureVal="$1"; shift
	_mongod_hack_ensure_no_arg_val "$ensureArg" "$@"
	mongodHackedArgs+=( "$ensureArg" "$ensureVal" )
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 36"
# _js_escape 'some "string" value'
_js_escape() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 37"
	jq --null-input --arg 'str' "$1" '$str'
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 38"

jsonConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-config.json"
tempConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-temp-config.json"
_parse_config() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 39"
	if [ -s "$tempConfigFile" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 40"
		return 0
	fi
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 41"
	local configPath
	if configPath="$(_mongod_hack_get_arg_val --config "$@")"; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 42"
		# if --config is specified, parse it into a JSON file so we can remove a few problematic keys (especially SSL-related keys)
		# see https://docs.mongodb.com/manual/reference/configuration-options/
		mongo --norc --nodb --quiet --eval "load('/js-yaml.js'); printjson(jsyaml.load(cat($(_js_escape "$configPath"))))" > "$jsonConfigFile"
		jq 'del(.systemLog, .processManagement, .net, .security)' "$jsonConfigFile" > "$tempConfigFile"
		return 0
	fi

	return 1
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 43"
dbPath=
_dbPath() {
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 44"
	if [ -n "$dbPath" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 45"
		echo "$dbPath"
		return
	fi

	if ! dbPath="$(_mongod_hack_get_arg_val --dbpath "$@")"; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 46"
		if _parse_config "$@"; then
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 47"
			dbPath="$(jq '.storage.dbPath' "$jsonConfigFile")"
		fi
	fi

	: "${dbPath:=/data/db}"

	echo "$dbPath"
}
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 48"
if [ "$originalArgOne" = 'mongod' ]; then
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 49"
	file_env 'MONGO_INITDB_ROOT_USERNAME'
	file_env 'MONGO_INITDB_ROOT_PASSWORD'
	# pre-check a few factors to see if it's even worth bothering with initdb
	shouldPerformInitdb=
	if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 50"
		# if we have a username/password, let's set "--auth"
		_mongod_hack_ensure_arg '--auth' "$@"
		set -- "${mongodHackedArgs[@]}"
		shouldPerformInitdb='true'
	elif [ "$MONGO_INITDB_ROOT_USERNAME" ] || [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 51"
		cat >&2 <<-'EOF'

			error: missing 'MONGO_INITDB_ROOT_USERNAME' or 'MONGO_INITDB_ROOT_PASSWORD'
			       both must be specified for a user to be created

		EOF
		exit 1
	fi

	if [ -z "$shouldPerformInitdb" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 51"
		# if we've got any /docker-entrypoint-initdb.d/* files to parse later, we should initdb
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh|*.js) # this should match the set of files we check for below
					shouldPerformInitdb="$f"
					echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 52"
					break
					;;
			esac
		done
	fi

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 53"

	# check for a few known paths (to determine whether we've already initialized and should thus skip our initdb scripts)
	if [ -n "$shouldPerformInitdb" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 54"
		dbPath="$(_dbPath "$@")"
		for path in \
			"$dbPath/WiredTiger" \
			"$dbPath/journal" \
			"$dbPath/local.0" \
			"$dbPath/storage.bson" \
		; do
			if [ -e "$path" ]; then
			echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 55"
				shouldPerformInitdb=
				break
			fi
		done
	fi

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 56"

	if [ -n "$shouldPerformInitdb" ]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 57"
		mongodHackedArgs=( "$@" )
		if _parse_config "$@"; then
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 58"
			_mongod_hack_ensure_arg_val --config "$tempConfigFile" "${mongodHackedArgs[@]}"
		fi
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 59"
		_mongod_hack_ensure_arg_val --bind_ip 127.0.0.1 "${mongodHackedArgs[@]}"
		_mongod_hack_ensure_arg_val --port 27017 "${mongodHackedArgs[@]}"

		# remove "--auth" and "--replSet" for our initial startup (see https://docs.mongodb.com/manual/tutorial/enable-authentication/#start-mongodb-without-access-control)
		# https://github.com/docker-library/mongo/issues/211
		_mongod_hack_ensure_no_arg --auth "${mongodHackedArgs[@]}"
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 60"
		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 61"
			_mongod_hack_ensure_no_arg_val --replSet "${mongodHackedArgs[@]}"
		fi
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 62"
		sslMode="$(_mongod_hack_have_arg '--sslPEMKeyFile' "$@" && echo 'allowSSL' || echo 'disabled')" # "BadValue: need sslPEMKeyFile when SSL is enabled" vs "BadValue: need to enable SSL via the sslMode flag when using SSL configuration parameters"
		_mongod_hack_ensure_arg_val --sslMode "$sslMode" "${mongodHackedArgs[@]}"

		if stat "/proc/$$/fd/1" > /dev/null && [ -w "/proc/$$/fd/1" ]; then
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 63"
			# https://github.com/mongodb/mongo/blob/38c0eb538d0fd390c6cb9ce9ae9894153f6e8ef5/src/mongo/db/initialize_server_global_state.cpp#L237-L251
			# https://github.com/docker-library/mongo/issues/164#issuecomment-293965668
			_mongod_hack_ensure_arg_val --logpath "/proc/$$/fd/1" "${mongodHackedArgs[@]}"
		else
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 64"
			initdbLogPath="$(_dbPath "$@")/docker-initdb.log"
			echo >&2 "warning: initdb logs cannot write to '/proc/$$/fd/1', so they are in '$initdbLogPath' instead"
			_mongod_hack_ensure_arg_val --logpath "$initdbLogPath" "${mongodHackedArgs[@]}"
		fi
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 65"
		_mongod_hack_ensure_arg --logappend "${mongodHackedArgs[@]}"

		pidfile="${TMPDIR:-/tmp}/docker-entrypoint-temp-mongod.pid"
		rm -f "$pidfile"
		_mongod_hack_ensure_arg_val --pidfilepath "$pidfile" "${mongodHackedArgs[@]}"

		"${mongodHackedArgs[@]}" --fork

		mongo=( mongo --host 127.0.0.1 --port 27017 --quiet )

		# check to see that our "mongod" actually did start up (catches "--help", "--version", MongoDB 3.2 being silly, slow prealloc, etc)
		# https://jira.mongodb.org/browse/SERVER-16292
		tries=30
		while true; do
		    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 66"
			if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
				# bail ASAP if "mongod" isn't even running
				echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 67"
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have stayed running -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 68"
			if "${mongo[@]}" 'admin' --eval 'quit(0)' &> /dev/null; then
				# success!
				echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 69"
				break
			fi
			echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 70"
			(( tries-- ))
			if [ "$tries" -le 0 ]; then
			echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 71"
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			sleep 1
		done

		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 72"

		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 73"
			rootAuthDatabase='admin'

			"${mongo[@]}" "$rootAuthDatabase" <<-EOJS
				db.createUser({
					user: $(_js_escape "$MONGO_INITDB_ROOT_USERNAME"),
					pwd: $(_js_escape "$MONGO_INITDB_ROOT_PASSWORD"),
					roles: [ { role: 'root', db: $(_js_escape "$rootAuthDatabase") } ]
				})
			EOJS
		fi
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 74"

		export MONGO_INITDB_DATABASE="${MONGO_INITDB_DATABASE:-test}"

		echo
		for f in /docker-entrypoint-initdb.d/*; do
		    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 75"
			case "$f" in
				*.sh) echo "$0: running $f"; . "$f" ;;
				*.js) echo "$0: running $f"; "${mongo[@]}" "$MONGO_INITDB_DATABASE" "$f"; echo ;;
				*)    echo "$0: ignoring $f" ;;
			esac
			echo
		done

		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 76"

		"$@" --pidfilepath="$pidfile" --shutdown
		rm -f "$pidfile"

		echo
		echo 'MongoDB init process complete; ready for start up.'
		echo
	fi

	unset "${!MONGO_INITDB_@}"
fi
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>> 77"
rm -f "$jsonConfigFile" "$tempConfigFile"

exec "$@"
