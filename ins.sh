#!/usr/bin/env bash

###########################################################################
# ubuntu use
# centos use

[[ -n $TOP_DIR ]] || export TOP_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

source "$TOP_DIR/local.conf"
source "$TOP_DIR/common/parameters.sh"
source "$TOP_DIR/common/services.sh"

main $@
