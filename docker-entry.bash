#!/bin/bash

init_cmds=()

# Get variables from the environment
# mariadb_root_password > MARIADB_ROOT_PASSWORD > MYSQL_ROOT_PASSWORD
mariadb_root_password=${mariadb_root_password:-$MARIADB_ROOT_PASSWORD} 
mariadb_root_password=${mariadb_root_password:-$MYSQL_ROOT_PASSWORD}

if [[ "$mariadb_root_password" ]]; then
    # We make a feeble attempt at preventing SQL injection problems
    mariadb_root_password=${mariadb_root_password//\'/\'\'}
    mariadb_root_password=${mariadb_root_password//\\/\\\\}
    init_cmds+=("update mysql.user set password=password('$mariadb_root_password') where user='root'")
    init_cmds+=("flush privileges")
fi

# printf '%s;\n' "${init_cmds[@]}"

# We use bootstrap instead of init-file since we don't really want to 
# keep the root password sitting around in some temporary file for the 
# full lifecycle of the image.
if [[ "$init_cmds" ]]; then
	exec mysqld "$@" --init-file=<(printf '%s;\n' "${init_cmds[@]}")
	#printf '%s;\n' "${init_cmds[@]}" \
	#| mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker \
	#|| exit
fi

exec mysqld "$@"

exit 1
