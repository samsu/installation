function _db_creation() {
# parameters:
#   $1 : username to access the databases with all priviliges
#   $2 : the user's password to access the database
#   $3 : the database name to be creating
#
    if [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ]; then
        echo -e "The input parameters are not completed or valid to create db,
_SERVICE_DB_USER=${_SERVICE_DB_USER}
_SERVICE_DB_PWD=${_SERVICE_DB_PWD}
_DB_NAME=${_DB_NAME}
"
        exit 9
    fi
 
    _SERVICE_DB_USER=$1
    _SERVICE_DB_PWD=$2
    _DB_NAME=$3

    mysqlshow -uroot -p$MYSQL_ROOT_PASSWORD ${_DB_NAME} 2>&1| grep -o "Database: ${_DB_NAME}" > /dev/nul
    if [ $? -ne 0 ]; then
        echo "Creating database ${_DB_NAME},  db user: '${_SERVICE_DB_USER}', db password: '****** ...'"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE ${_DB_NAME};"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON ${_DB_NAME}.* TO '${_SERVICE_DB_USER}'@'%' IDENTIFIED BY '${_SERVICE_DB_PWD}';"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON ${_DB_NAME}.* TO '${_SERVICE_DB_USER}'@'localhost' IDENTIFIED BY '${_SERVICE_DB_PWD}';"
    fi
}


function _services_db_creation() {
    for service in $SERVICES; do
        eval SERVICE_DB_USER=\$$(echo DB_USER_${service^^})
        eval SERVICE_DB_PWD=\$$(echo DB_PWD_${service^^})

        _db_creation $SERVICE_DB_USER $SERVICE_DB_PWD $service

        if [[ ${service,,} == 'nova' ]]; then
            _db_creation $SERVICE_DB_USER $SERVICE_DB_PWD nova_api
            _db_creation $SERVICE_DB_USER $SERVICE_DB_PWD nova_cell0
        fi
        echo "The database for ${service} was created."
    done
}

