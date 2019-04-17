#!/bin/bash
#
# Calculates some stats for running programs.
# Takes the program name as an argument
# Finds all processes with the specified name and calculates their stats using pidstat.
# mem usage, I/O, cpu usage.
# Aggregates:
# SUM of values for all processes
# MIN value of all processes
# MAX value of all processes
# AVG value for all processes
# COUNT of all processes

SUDO=/usr/bin/sudo
PIDSTAT=/usr/bin/pidstat
AWK=/usr/bin/awk
TMP_TEMPLATE="/tmp/zabbix."
types_stat="vsz rss pmem ioread iowrite cpu_user cpu_system"
aggregate_functions="min max avg sum"

PROG_NAME=$1
RESOURCE=$2
AGG_TYPE=$3
MAXCOUNT=10
CACHEAGE=90

if [ ! -x $PIDSTAT ]; then
    echo command $PIDSTAT not found
    exit 1
fi

if [ ! ${PROG_NAME} ]; then
    echo PROG_NAME not specified
    exit 1
fi

if [ ! ${RESOURCE} ]; then
    if [ "${PROG_NAME}" == "_LLD" ]; then
        RESOURCE=lld
    else
        echo RESOURCE not specified
        exit 1
    fi
fi

if [ ! ${AGG_TYPE} ]; then
    AGG_TYPE=sum
fi


# get_stat_in_bytes
# REPORT_OPTION
#   -d | -r | -u option for call pidstat
# COLUMN_NUMBER - column number with required values
# AGG - aggregate function
#   min max avg sum
function get_stat_in_bytes () {
    REPORT_OPTION=$1
    COLUMN_NUMBER=$2
    AGG=$3
    STATFILE=`echo -n ${PROG_NAME} | sed 's/\//_/g'`
    STATFILE=${TMP_TEMPLATE}${STATFILE}.${REPORT_OPTION}.pidstat
    NOW=`date +%s`
    LASTMOD=0
    if [ -r $STATFILE ]; then
        LASTMOD=`stat -c "%Y" $STATFILE`
    fi
    let "AGE = $NOW - $LASTMOD"
    if [ $AGE -gt $CACHEAGE ]; then
        $SUDO $PIDSTAT -C $PROG_NAME ${REPORT_OPTION} -p ALL 1 $MAXCOUNT | grep "^Average:" > $STATFILE
    fi
    if [ ! -s $STATFILE ]; then 
        sleep $MAXCOUNT
    fi
    case "${AGG}" in
        "min" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MIN == "" || MIN > $column ) { MIN=$column }} END {print int(MIN*1024)}' $STATFILE
        ;;
        "max" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MAX == "" || MAX < $column ) { MAX=$column }} END {print int(MAX*1024)}' $STATFILE
        ;;
        "avg" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END { print (NR>1)?int((SUM*1024)/(NR-1)):0 }' $STATFILE
        ;;
        * )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END {print int(SUM*1024)}' $STATFILE
        ;;
    esac
}

# get_stat_as_is
# REPORT_OPTION
#   -d | -r | -u option for call pidstat
# COLUMN_NUMBER - column number with required values
# AGG - aggregate function
#   min max avg sum
function get_stat_as_is () {
    REPORT_OPTION=$1
    COLUMN_NUMBER=$2
    AGG=$3
    STATFILE=`echo -n ${PROG_NAME} | sed 's/\//_/g'`
    STATFILE=${TMP_TEMPLATE}${STATFILE}.${REPORT_OPTION}.pidstat
    NOW=`date +%s`
    LASTMOD=0
    if [ -r $STATFILE ]; then
        LASTMOD=`stat -c "%Y" $STATFILE`
    fi
    let "AGE = $NOW - $LASTMOD"
    if [ $AGE -gt $CACHEAGE ]; then
        $SUDO $PIDSTAT -C $PROG_NAME ${REPORT_OPTION} -p ALL 1 $MAXCOUNT | grep "^Average:" > $STATFILE
    fi
    if [ ! -s $STATFILE ]; then 
        sleep $MAXCOUNT
    fi
    case "${AGG}" in
        "min" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MIN == "" || MIN > $column ) { MIN=$column }} END {print MIN}' $STATFILE
        ;;
        "max" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MAX == "" || MAX < $column ) { MAX=$column }} END {print MAX}' $STATFILE
        ;;
        "avg" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END { print (NR>1)?SUM/(NR-1):0 }' $STATFILE
        ;;
        * )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END {print SUM}' $STATFILE
        ;;
    esac
}

# get_count
# Report the count of running program's instances
function get_count () {
    # -1 call of this program
    # -2 grep
    # -3 expr
    expr `ps ax | grep "$PROG_NAME" | wc -l` - 3
}


# LLD mode
# In LLD mode, the script returns a list of names of all running processes.
# Use it with caution.
# It produces 25 items for each process, therefore you can get a huge summary list of items.
function lld () {
    echo {\"data\":[
    for program in `ps ax -o comm=Command | tail -n +2 | sort | uniq` ; do
        for stat in $types_stat ; do
            for func in $aggregate_functions ; do
                echo {\"{#PROGNAME}\":\"$program\", \"{#STATSNAME}\":\"$stat\", \"{#AGG_FUNC}\":\"$func\"},
            done
        done
        echo {\"{#PROGNAME}\":\"$program\", \"{#STATSNAME}\":\"count\", \"{#AGG_FUNC}\":\"count\"},
    done
    echo {\"{#MODE}\":\"_LLD\"}
    echo ]}
}

case "${RESOURCE}" in
    "vsz" )
        get_stat_in_bytes -r 6 $AGG_TYPE
    ;;
    "rss" )
        get_stat_in_bytes -r 7 $AGG_TYPE
    ;;
    "pmem" )
        get_stat_as_is -r 8 $AGG_TYPE
    ;;
    "ioread" )
        get_stat_in_bytes -d 4 $AGG_TYPE
    ;;
    "iowrite" )
        get_stat_in_bytes -d 5 $AGG_TYPE
    ;;
    "cpu_user" )
        get_stat_as_is -u 4 $AGG_TYPE
    ;;
    "cpu_system" )
        get_stat_as_is -u 5 $AGG_TYPE
    ;;
    "count" )
        get_count
    ;;
    "lld" )
        lld
    ;;
    * )
        echo Wrong resource type. Must be: $types_stat
        exit 1
    ;;
esac
