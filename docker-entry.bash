#!/bin/bash

# Environment variables:
# mariadb_random_root_password=1 boolean
#   Generate random password for root user? Otherwise it's blank.
# mariadb_init_empty_datadir=1 boolean
#   Initialize empty datadir, or leave it alone?
# mariadb_verbose_entry=0 boolean
#   Should this entrypoint script output verbose info about its activities?

# bootstrap_cmds is used to hold commands that are executed by a bootstrap instance of mysqld
# before the real server is started.
declare -a bootstrap_cmds

# This init_cmds thing is leftover from my previous attempt to use --init-file to set the root
# password. That didn't work out when starting mysqld as root using --user=mysql, which may be
# necessary to use external volumes. I'm leaving it in case it has some use later.
declare -a init_cmds

# And setup_cmds is used with mysql_embedded before the server is started.
declare -a setup_cmds

# mariadb_verbose_entry / MARIADB_VERBOSE_ENTRY
# Default: 0 for quiet startup, 1 for verbose logging
mariadb_verbose_entry=${mariadb_verbose_entry:-$MARIADB_VERBOSE_ENTRY}
case ${mariadb_verbose_entry,,} in 
    true|1)  mariadb_verbose_entry=1;;
         *)  mariadb_verbose_entry=0;;
esac
dbg=$mariadb_verbose_entry

log() {
	printf '%s\n' "$@" >&2
}

# mariadb_init_empty_datadir / MARIADB_INIT_EMPTY_DATADIR
# Default: 1 to init, 0 to leave it empty/alone
mariadb_init_empty_datadir=${mariadb_init_empty_datadir:-$MARIADB_INIT_EMPTY_DATADIR}
case ${mariadb_init_empty_datadir,,} in
    false|0) mariadb_init_empty_datadir=0;;
          *) mariadb_init_empty_datadir=1;;
esac

# If mysql database is missing from datadir, we run mysql_install_db unless someone has 
# explicitly set mariadb_init_empty_datadir=0
if [[ ! -d /var/lib/mysql/mysql ]] && ((mariadb_init_empty_datadir)); then
	((dbg)) && log "Initializing datadir"
	mysql_install_db --user=mysql
	is_bootstrap=1
	setup_cmds+=(
		"delete from mysql.user where user <> 'root'"
		"delete from mysql.user where host <> 'localhost'"
                "delete from mysql.db"
		"insert into mysql.plugin values ('SEQUENCE', 'ha_sequence.so')"
		)
fi

[[ -e /var/lib/mysql/docker_bootstrap ]]  && is_bootstrap=1

# mariadb_random_root_password / MARIADB_RANDOM_ROOT_PASSWORD
# Default: 1 if we're bootstrapping, otherwise 0
mariadb_random_root_password=${mariadb_random_root_password:-$MARIADB_RANDOM_ROOT_PASSWORD}
((is_bootstrap)) && mariadb_random_root_password=${mariadb_random_root_password:-1}
case ${mariadb_random_root_password,,} in
    true|1) mariadb_random_root_password=1;;
         *) mariadb_random_root_password=0;;
esac


# By default, set a random password when the container is executed. The user can use ''docker exec''
# to invoke command-line tools that will automatically log in as root with the configured password.
# It's easy to change it like this:
#   docker exec -ti <container> mysqladmin password newpass
if ((mariadb_random_root_password)); then
	((dbg)) && log "Setting random root password"

	mypass=$(dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64)

	setup_cmds+=("UPDATE mysql.user SET password=password('$mypass') WHERE user='root'")

	declare -a my_cnf
	[[ -e .my.cnf ]] || my_cnf+=('[client]' 'user=root')
	my_cnf+=("password=$mypass")
	printf %s\\n "${my_cnf[@]}" >> .my.cnf
fi
rm -f /var/lib/mysql/docker_bootstrap


if ((${#bootstrap_cmds[@]})); then
	((dbg)) && log "Executing bootstrap_cmds"
	printf '%s;\n' "${bootstrap_cmds[@]}"  |
  mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker
fi

if ((${#setup_cmds[@]})); then
	((dbg)) && log "Executing setup_cmds"
	declare -a mysql_embedded_args
	mysql_embedded_args=( 
		--server-arg='--skip-innodb' 
		--server-arg='--default-storage-engine=myisam'
		)
	for arg in "${setup_cmds[@]}"; do
		mysql_embedded_args+=(-e "$arg;")
	done
	mysql_embedded "${mysql_embedded_args[@]}"
fi

# As above, this init_cmds logic originally existed to support setting the password. It stays
# in case it's of use later for setting something else.
((${#init_cmds[@]})) && exec mysqld "$@" --init-file=<(printf '%s;\n' "${init_cmds[@]}")

exec mysqld "$@"

# There should be no chance of arriving here, but if we get sucked into a 
# singularity, we may as well exit the script reponsibly.
exit 1
