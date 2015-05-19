#!/bin/bash

# Originally I was setting the root password using environment variables,
# as is done by the MariaDB/MySQL images on Docker Hub, but that's a huge
# security problem. The environment variable is accessible to any process
# or user on the container, as well as by any linked containers. This is
# an unacceptable security risk, so we will not support the use of ENV
# variables for any sensitive data.

# But maybe we want to support something else later in --init-file, so I'm
# keeping this skeleton around Just In Case.

init_cmds=()

# printf '%s;\n' "${init_cmds[@]}"

if [[ "$init_cmds" ]]; then
	exec mysqld "$@" --init-file=<(printf '%s;\n' "${init_cmds[@]}")
	#printf '%s;\n' "${init_cmds[@]}" \
	#| mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker \
	#|| exit
fi

exec mysqld "$@"

# There should be no chance of arriving here, but if we get sucked into a 
# singularity, we may as well exit the script reponsibly.
exit 1
