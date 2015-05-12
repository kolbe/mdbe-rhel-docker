#!/bin/bash

init_cmds=()

if [[ "$MYSQL_ROOT_PASSWORD" ]]; then
    # We make a feeble attempt at preventing SQL injection problems
    MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD//\'/\'\'}
    MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD//\\/\\\\}
    init_cmds+=("update mysql.user set password=password('$MYSQL_ROOT_PASSWORD') where user='root'")
fi

#printf '%s;\n' "${init_cmds[@]}"

# We use bootstrap instead of init-file since we don't really want to 
# keep the root password sitting around in some temporary file for the 
# full lifecycle of the image.
if [[ "$init_cmds" ]]; then
	printf '%s;\n' "${init_cmds[@]}" \
	| mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker \
	|| exit
fi

exec mysqld "$@"

exit 1
