#!/usr/bin/env bash


function _ERRTRAP() {
    FILENAME="$PWD/$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
    INFO="[FILE: $FILENAME, LINE: $1] Error: The following command or function exited with status $2
    $(sed -n $1p $FILENAME)

"
    echo -e "$INFO"
}

function _import_config() {
    ## If any parameter's name is changed, the new name need to be defined and
    ## it's related references need to be replaced as below.
    ## e.g.
    ##   admin_password
    ##  ==>
    ##   ${KEYS[$INS_OPENSTACK_RELEASE,KEYSTONE_U_PWD_GLANCE]:-admin_password}
    _CONF_PATH="$TOP_DIR/conf/${INS_OPENSTACK_RELEASE,,}"
    _DB_CREATION="$_CONF_PATH/db_creation.sh"

    source $_DB_CREATION

    for service in $SERVICES horizon; do
        CONF="$_CONF_PATH/${service}_config.sh"
        if [ -e $CONF ]; then
            source $CONF
        else
            echo "cannot found the file $CONF"
            exit 8
        fi
    done
}

function loadvars() {
    varname=${1,,}
    eval var=\$$(echo $1)

    if [[ -z $var ]]; then
        echo -e "\x1b[32mPlease enter the $varname (Example: $2):\x1b[37m"
        while read input
        do
            if [ "$input" == "" ]; then
                echo "Default $varname '$2' chosen"
                export $(echo $1)="$2"
                break
            else
                echo "You have entered $input"
                export $(echo $1)="$input"
                break
            fi
        done
    fi
}

function _help() {
    usage=$(echo "$(< $TOP_DIR/docs/help.txt)")

    if [ "$#" -eq 0 ]; then
        SUPPORTED_VER=${SUPPORTED_OPENSTACK_RELEASE[@]}
        LATEST_VER=${SUPPORTED_OPENSTACK_RELEASE[-1]}
        echo "$usage" | \
        sed -r "s#SUPPORTED_OPENSTACK_RELEASE#$SUPPORTED_VER#g" | \
        sed -r "s#LATEST_OPENSTACK_RELEASE#$LATEST_VER#g"
        exit 6
    fi
    while getopts ':hv:' option; do
        case "$option" in
        h)  echo "$usage"
            exit
            ;;
        v)  local version=${OPTARG,,}
            local _SUPPORTED=FALSE
            for VER in ${SUPPORTED_OPENSTACK_RELEASE[@]}; do
                if [[ $VER == "$version" ]]; then
                    _SUPPORTED=TRUE
                    INS_OPENSTACK_RELEASE=$VER
                    break
                fi
            done
            if [[ $_SUPPORTED != "TRUE" ]]; then
                echo -e "
Error: The assigned Openstack version is not supported so far,
the supported openstack version were listed as below:
${SUPPORTED_OPENSTACK_RELEASE[@]}
"
                exit 3
            fi
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 2
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        esac
    done
    return $((OPTIND - 1))
}


function _display() {
    # starting need to be run on the beginning
    if [[ "$*" == "starting" ]]; then
        _repo_epel $*
        sudo yum -y install figlet crudini >& /dev/null
        if [[ "$?" != "0" ]]; then
            echo "Failed to install the package figlet"
            exit 4
        fi
        figlet -tf slant Openstack installer && echo

    elif [[ "$*" == "completed" ]]; then
        figlet -tf slant Openstack installation $1
        echo -e "It takes\x1b[32m $SECONDS \x1b[0mseconds during the installation."
        echo "$LOGIN_INFO"

    else
        figlet -tf slant Openstack installation $1
    fi
}


function _log() {
    ## Log the script all outputs locally
    exec > >(sudo tee install.log)
    exec 2>&1
}


function _installation() {
    _base
    for service in "$@"; do
        echo "##### Installing $service ..."
        $service || exit $?
    done
}


function _timestamp {
    awk '{ print strftime("%Y-%m-%d %H:%M:%S | "), $0; fflush(); }'
}


function _wait() {
    set +x
    num=$(echo "$*" | grep -o '[0-9]\+')
    i=0
    while [ "$i" -le "$num" ] ; do
        for c in / - \\ \|; do
            printf '%s\b' "$c"
            sleep 0.25
        done
        ((i++))
    done
    set -x
}
