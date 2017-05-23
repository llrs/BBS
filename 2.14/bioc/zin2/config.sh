#!/bin/bash
# ====================
# Settings for zin2
# ====================



#set -x  # print commands and their arguments as they are executed

export BBS_DEBUG="0"

export BBS_NODE_HOSTNAME="zin2"
export BBS_USER="biocbuild"
export BBS_RSAKEY="/home/biocbuild/.BBS/id_rsa"
export BBS_WORK_TOPDIR="/home/biocbuild/bbs-2.14-bioc"
export BBS_R_HOME="$BBS_WORK_TOPDIR/R"
export BBS_NB_CPU=5


export RCYTOSCAPE_PORT_OVERRIDE="9028"
export RCYTOSCAPE_HOST_OVERRIDE="wilson1"

export GENE_E_URL="http://wilson2:9997"

export R_TEXI2DVICMD=/home/biocbuild/BBS/utils/ourtexi2dvi

# Shared settings (by all Unix nodes).

wd0=`pwd`
cd ..
. ./config.sh
cd "$wd0"



# Needed only on the node performing stage6 (must be run on the
# BBS_CENTRAL_RHOST machine).
#

# If you are NOT using a bi-arch builder (i.e. moscato1 or moscato2) to
# create your Windows build products, the following note applies:

# IMPORTANT NOTE: The win.binary mapping must either include the 2
# Windows nodes (win32 and win64) or not be present at all. Temporarily
# dropping a Windows node will allow some single-arch Windows binary
# packages to propagate and to later not be replaced by the bi-arch when
# the dropped node is back.

export BBS_OUTGOING_MAP="source:zin2/buildsrc win.binary:moscato2/buildbin mac.binary:petty/buildbin mac.binary.mavericks:morelia/buildbin"

# Needed only on the node performing stage8 (BBS-report.py)
#
# IMPORTANT: BBS-report.py will treat BBS_REPORT_PATH as a _local_ path so it
# must be run on the BBS_CENTRAL_RHOST machine.

export BBS_REPORT_NODES="zin2 moscato2:bin petty:bin morelia:bin"
#export BBS_SVNCHANGELOG_URL="http://fgc.lsi.umich.edu/cgi-bin/blosxom.cgi"
export BBS_REPORT_PATH="$BBS_CENTRAL_RDIR/report"
export BBS_REPORT_CSS="$BBS_HOME/$BBS_BIOC_VERSION/report.css"
export BBS_REPORT_JS="$BBS_HOME/$BBS_BIOC_VERSION/report.js"
export BBS_REPORT_DEST_DIR="webadmin@master.bioconductor.org:/extra/www/bioc/checkResults/$BBS_BIOC_VERSION/bioc-LATEST"
export BBS_PUBLISHED_REPORT_URL="http://master.bioconductor.org/checkResults/$BBS_BIOC_VERSION/bioc-LATEST/"
export BBS_NOTIFY_NODES="zin2"
