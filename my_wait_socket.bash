#!/usr/bin/env bash

timeout=60

socket=$(my_print_defaults server | awk -F= '/--socket/{print $2}')
[[ $socket ]] || socket=$(mysqld --help --verbose 2>/dev/null | awk '/^socket/{print $2}')

if [[ ! $socket ]]; then
    echo "[ERROR] could not determine socket file" >&2
    exit 1
fi

for ((i=0;i<timeout;i++)); do
   [[ -e $socket ]] && exit
   sleep 1
done

echo "[ERROR] timed out after $timeout seconds" >&2
exit 1
