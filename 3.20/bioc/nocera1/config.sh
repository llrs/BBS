#!/bin/bash
# ====================
# Settings for nocera1 
# ====================



#set -x  # print commands and their arguments as they are executed

export BBS_DEBUG="0"

export BBS_NODE_HOSTNAME="nocera1"
export BBS_USER="biocbuild"
export BBS_WORK_TOPDIR="/home/biocbuild/bbs-3.20-bioc"
export BBS_R_HOME="$BBS_WORK_TOPDIR/R"
export R_LIBS="$BBS_R_HOME/site-library"

# nocera1 has 16 logical CPUs.
export BBS_NB_CPU=13
export BBS_BUILD_NB_CPU=13
export BBS_CHECK_NB_CPU=15

# Central build node is bbscentral1 on Jetstream2.
export BBS_CENTRAL_RHOST="bbscentral1"
export BBS_RSH_CMD="ssh -F /home/biocbuild/.ssh/config"
export BBS_CENTRAL_ROOT_URL="http://149.165.171.124"
export BBS_PRODUCT_TRANSMISSION_MODE="asynchronous"



# Shared settings (by all Unix nodes).

wd0=$(pwd)
cd ..
. ./config.sh
cd "$wd0"
