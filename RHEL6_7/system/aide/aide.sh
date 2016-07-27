#!/bin/bash

. /usr/share/preupgrade/common.sh

#END GENERATED SECTION
COMPONENT="aide"
AIDE_LOG="/var/log/aide/aide.log"
FOUND=0

# Aide installed but never run
if [[ ! -f $AIDE_LOG ]]; then
    log_info "AIDE was installed but never run."
    exit $RESULT_INFORMATIONAL
fi

log_medium_risk "AIDE is being used for 'guarding' the system integrity."
exit $RESULT_FAIL
