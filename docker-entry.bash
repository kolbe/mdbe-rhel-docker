#!/bin/bash

# mariadb_random_root_password / MARIADB_RANDOM_ROOT_PASSWORD
# Default: 1
# Generate random password for root user? Otherwise it's blank.
mariadb_random_root_password=${mariadb_random_root_password:-$MARIADB_RANDOM_ROOT_PASSWORD}
mariadb_random_root_password=${mariadb_random_root_password:-1}

# This init_cmds thing is leftover from my previous attempt to use --init-file to set the root
# password. That didn't work out when starting mysqld as root using --user=mysql, which may be
# necessary to use external volumes. I'm leaving it in case it has some use later.
init_cmds=()

printf %s\\n '[client]' 'user=root' >> ~/.my.cnf

if [[ ! -d /var/lib/mysql/mysql ]]; then
	mysql_install_db --user=mysql
fi

# By default, set a random password when the container is executed. The user can use ''docker exec''
# to invoke command-line tools that will automatically log in as root with the configured password.
# It's easy to change it like this:
#   docker exec -ti <container> mysqladmin password newpass
if ((mariadb_random_root_password)) || [[ ${mariadb_random_root_password,,} = true ]]; then

	mypass=$(dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64)

	printf %s\\n "UPDATE mysql.user SET password=password('$mypass');" |
	  mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker

	printf password=%s\\n "$mypass" >> ~/.my.cnf
fi

# As above, this init_cmds logic originally existed to support setting the password. It stays
# in case it's of use later for setting something else.
if ((${#init_cmds[@]})); then
	exec mysqld "$@" --init-file=<(printf '%s;\n' "${init_cmds[@]}")
else
	exec mysqld "$@"
fi

# There should be no chance of arriving here, but if we get sucked into a 
# singularity, we may as well exit the script reponsibly.
exit 1
