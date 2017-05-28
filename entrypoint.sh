#!/bin/bash
set -e

source ${GITLAB_RUNTIME_DIR}/functions

[[ $DEBUG == true ]] && set -x

case ${1} in
  app:init|app:start|app:sanitize|app:rake)

    initialize_system
    configure_gitlab
    configure_gitlab_shell
    configure_nginx

    # patching gilab to allow shorter passwords
    sed -i -e 's;config.password_length = .\.\.128;config.password_length = 2..128;' /home/git/gitlab/config/initializers/devise.rb

    case ${1} in
      app:start)
        migrate_database
        rm -rf /var/run/supervisor.sock
        printenv | sed 's/^\(.*\)\=\(.*\)$/export \1\="\2"/g' | sort > /.env
        exec /usr/bin/supervisord -nc /etc/supervisor/supervisord.conf
        ;;
      app:init)
        migrate_database
        ;;
      app:sanitize)
        sanitize_datadir
        ;;
      app:rake)
        shift 1
        execute_raketask $@
        ;;
    esac
    ;;
  app:help)
    echo "Available options:"
    echo " app:start        - Starts the gitlab server (default)"
    echo " app:init         - Initialize the gitlab server (e.g. create databases, compile assets), but don't start it."
    echo " app:sanitize     - Fix repository/builds directory permissions."
    echo " app:rake <task>  - Execute a rake task."
    echo " app:help         - Displays the help"
    echo " [command]        - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
