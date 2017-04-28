#!/usr/bin/env bash

###########################################################################
# ubuntu use
# eth0=$(ip address show eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
# centos use
# export TOP_DIR=$(cd $(dirname "$0") && pwd)
[[ -n $TOP_DIR ]] || export TOP_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

source "$TOP_DIR/local.conf"
source "$TOP_DIR/common/parameters.sh"
source "$TOP_DIR/common/services.sh"

main $@
