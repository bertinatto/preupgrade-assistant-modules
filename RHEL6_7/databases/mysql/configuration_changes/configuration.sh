#!/bin/bash


. /usr/share/preupgrade/common.sh

#END GENERATED SECTION

# This check can be used if you need root privilegues
check_root

source ../mysql-common.sh

# filters comments that has # in the beggining of the line from stdin
filter_comments() {
    grep -v -e '^[[:space:]]*$' -e '^[[:space:]]*#' | sed 's|[[:space:]]*#.*||'
}

export OPTION_NOT_OK_FILE=option_not_ok
export OPTION_FIXED_FILE=option_fixed
export tmp_file=$(mktemp .mysqlconfigXXX --tmpdir=/tmp)
rm -f $OPTION_NOT_OK_FILE
rm -f $OPTION_FIXED_FILE


medium_unsup_plug=0
high_unsup_innodb=0
high_depre_lang=0

# check options in file $1
# recursion level is in $2
check_options() {
    # recursion level limit so we do not cycle for ever
    [ $# -ne 2 ] && log_warning "check_options accepts 2 arguments" && return 1
    [ $2 -gt 5 ] && log_warning "check_options recursion level exceeded" && return 2
    CONFIG_FILE=$1
    log_debug  "checking config file $CONFIG_FILE"
    backup_config "$CONFIG_FILE"
    BACKUPED_CONFIG_FILE="${VALUE_TMP_PREUPGRADE}/$CONFIG_FILE"

    # remove comments and empty lines
    filtered_conf="$(cat "$CONFIG_FILE" | filter_comments)"

    # starting from MariaDB/MySQL 5.5, innodb is the default storage engine,
    # so innodb plugin is not possible to be installed any more.
    echo "$filtered_conf" | grep -e 'plugin-load=innodb=' >/dev/null
    innodb_plugin_loaded=$?
    echo "$filtered_conf" | grep -e 'ignore-builtin-innodb' >/dev/null
    builtin_innodb_ignored=$?
    if [ $innodb_plugin_loaded -eq 0 ] && [ $builtin_innodb_ignored -eq 1 ]; then
        echo "innodb_plugin_loaded" >> "$tmp_file"
        log_medium_risk "${CONFIG_FILE}: option 'plugin-load=innodb=' is not supported"
        sed -i -e 's/plugin-load=innodb=/#plugin-load=innodb=/g' $BACKUPED_CONFIG_FILE
        [ $? -eq 0 ] \
            && echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_FIXED_FILE" \
            || echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_NOT_OK_FILE"
    fi

    # innodb_file_io_threads changed to innodb_read_io_threads and innodb_write_io_threads
    echo "$filtered_conf" | grep -e 'innodb_file_io_threads' >/dev/null
    if [ $? -eq 0 ]; then
        echo "innodb_file_io_threads" >> "$tmp_file"
        log_high_risk "${CONFIG_FILE}: option 'innodb_file_io_threads' is not supported"
        sed -i -e 's/innodb_file_io_threads/#innodb_file_io_threads/g' $BACKUPED_CONFIG_FILE
        [ $? -eq 0 ] \
            && echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_FIXED_FILE" \
            || echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_NOT_OK_FILE"
    fi

    # language changed to lc_messages_dir and lc_messages
    echo "$filtered_conf" | grep -e 'language\s*=' >/dev/null
    if [ $? -eq 0 ]; then
        echo "language" >> "$tmp_file"
        log_high_risk "${CONFIG_FILE}: option 'language' is deprecated"
        sed -i -e 's/language\s*=/#language=/g' $BACKUPED_CONFIG_FILE
        [ $? -eq 0 ] \
            && echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_FIXED_FILE" \
            || echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_NOT_OK_FILE"
    fi

    for i in log-bin-trust-routine-creators table_lock_wait_timeout ; do
        echo "$filtered_conf" | grep $i >/dev/null
        if [ $? -eq 0 ]; then
            echo "obsolete_options_used" >> "$tmp_file"
            log_high_risk "${CONFIG_FILE}: option '$i' was removed in MariaDB 5.5"
            sed -i -e "s/${i}\s*/#${i}/g" $BACKUPED_CONFIG_FILE
            [ $? -eq 0 ] \
                && echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_FIXED_FILE" \
                || echo "$BACKUPED_CONFIG_FILE" >> "$OPTION_NOT_OK_FILE"
        fi
    done

    # directive include includes the specified configuration file
    echo "$filtered_conf" | grep -uhe '!include[[:space:]]' \
                          | sed -e 's/.*!include[[:space:]]*\([^#]*\).*$/\1/' \
                          | while read includefile ; do
        if [ -f "$includefile" ] ; then
            check_options "$includefile" $(($2 + 1)) \
                || echo "$includefile" >> "$OPTION_NOT_OK_FILE"
        fi
    done

    # directive includedir includes all configuration files *.cnf
    echo "$filtered_conf" | grep -uhe '!includedir[[:space:]]' \
                          | sed -e 's/.*!includedir[[:space:]]*\([^#]*\).*$/\1/' \
                          | while read includedir ; do
        for includefile in ${includedir}/*.cnf ; do
            if [ -f "$includefile" ] ; then
                check_options "$includefile" $(($2 + 1)) \
                    || echo "$includefile" >> "$OPTION_NOT_OK_FILE"
            fi
        done
    done

}

# we don't check users' configurations, since they don't provide
# server configuration
check_options /etc/my.cnf 1 || echo "/etc/my.cnf" >> "$OPTION_NOT_OK_FILE"
result=$RESULT_INFORMATIONAL

grep -q "^innodb_plugin_loaded" "$tmp_file" && {

        cat >> $SOLUTION_FILE <<EOF

* The InnoDB plugin is now a default storage engine in MariaDB 5.5.
This configuration is using the old plugin-load=innodb= configuration option.
You must either remove this directive from the configuration files or use
ignore-builtin-innodb as the current directives will not work.
EOF
}

grep -q "^innodb_file_io_threads" "$tmp_file" && {
        cat >> $SOLUTION_FILE <<EOF

* The configuration option innodb_file_io_threads was removed in MariaDB 5.5
and replaced with innodb_read_io_threads and innodb_write_io_threads.
To ensure proper functionality, please change your configuration to use the
new configuration directives.
EOF
}

grep -q "^language$" "$tmp_file" && {
        cat >> $SOLUTION_FILE <<EOF

* MySQL 5.1 used the language variable for specifying the directory which
included the error message file. This option is now deprecated and has been
replaced by the lc_messages_dir and lc_messages options.
This also applies to options in the configuration files.
EOF
}

grep -q "^obsolete_options_used" "$tmp_file" && {
 cat >> $SOLUTION_FILE <<EOF

* The options log-bin-trust-routine-creators and table_lock_wait_timeout specified in your MySQL configuration files are not supported in MariaDB 5.5.
They must be removed.
EOF
}

if [ -f "$OPTION_FIXED_FILE" ] ; then
    # this is not fixed really - files still need modification by user if he want to
    # have really "same" behaviour as in old system
    #echo "Some configuration files were fixed" >> solution.txt
    echo -e "\n
To provide at least basic funcionality, some options were commented out
in the files listed below.
You should replace them with options suitable for your environment that
provide the same functionality as you have now:" >> "$SOLUTION_FILE"
    if [ -f "$OPTION_NOT_OK_FILE" ]; then
      # print only files which are not inside $OPTIONS_NOT_OK_FILE
      grep -vwF "$(cat "$OPTION_NOT_OK_FILE" | sort | uniq)" "$OPTION_FIXED_FILE" \
        | sort | uniq  >> "$SOLUTION_FILE"
    else
      cat "$OPTION_FIXED_FILE" | sort | uniq >> "$SOLUTION_FILE"
    fi
    result=$RESULT_FAILED
fi

if [ ! -f "$OPTION_NOT_OK_FILE" ]; then
    [ ! -f "$OPTION_FIXED_FILE" ] \
      && log_info "No option problems found in MySQL configuration."
else
    echo "\n
Some options were not commented out in files listed below and therefore MariaDB 5.5 may unexpectedly crash.
The listed options should be replaced or commented out manually:" >> "$SOLUTION_FILE"
    cat "$OPTION_NOT_OK_FILE" | sort | uniq >> "$SOLUTION_FILE"
    result=$RESULT_FAILED
fi

[ "$result" == "$RESULT_FAILED" ] && echo "
The files mentioned above are backups of your original configuration files.
After the upgrade you must manually replace the contents of the default
MariaDB 5.5 configuration (as is appropriate to your environment), with the
information provided about replaced or deprecated options listed in the
backups.  You must restart MariaDB for these changes to take effect.
"

rm -f "$tmp_file"
exit $result
