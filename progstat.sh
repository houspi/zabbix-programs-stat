#!/bin/bash
#
# Calculates some stats for running programs.
# Takes the program name as an argument
# Finds all processes with the specified name and calculates their stats using pidstat.
# mem stat, I/O stat, cpu stat.
# SUM of values for all processes
# MIN value from all processes
# MAX value from all processes
# AVG value for all processes
# COUNT of all processes

SUDO=/usr/bin/sudo
PIDSTAT=/usr/bin/pidstat
AWK=/usr/bin/awk
TMP_TEMPLATE="/tmp/zabbix."

PROG_NAME=$1
RESOURCE=$2
AGG_TYPE=$3
MAXCOUNT=10
CACHEAGE=60

if [ ! -x $PIDSTAT ]; then
    echo command $PIDSTAT not found
    exit 1
fi
if [ ! ${PROG_NAME} ]; then
    PROG_NAME=_lld
fi
if [ ! ${RESOURCE} ]; then
    RESOURCE=lld
fi
if [ ! ${AGG_TYPE} ]; then
    AGG_TYPE=sum
fi


# get_cpustat
# Report CPU utilization.
# CPUTYPE - cpu utilization type column number
#   4 - user level
#   5 - system level (kernel)
# AGG - aggregate function
#   min max avg sum
function get_cpustat () {
    CPUTYPE=$1 
    AGG=$2
    NOW=`date +%s`
    LASTMOD=0
    STATFILE=`echo -n ${PROG_NAME} | sed 's/\//_/g'`
    STATFILE=${TMP_TEMPLATE}${STATFILE}.cpu.pidstat
    if [ -r $STATFILE ]; then
        LASTMOD=`stat -c "%Y" $STATFILE`
    fi
    let "AGE = $NOW - $LASTMOD"
    if [ $AGE -gt $CACHEAGE ]; then
        $SUDO $PIDSTAT -C $PROG_NAME -u -p ALL 1 $MAXCOUNT | grep "^Average:" > $STATFILE
    fi
    case "${AGG}" in
        "min" )
            $AWK -v column="$CPUTYPE" 'NR>1 {if( MIN == "" || MIN > $column ) { MIN=$column }} END {print int(MIN)}' $STATFILE
        ;;
        "max" )
            $AWK -v column="$CPUTYPE" 'NR>1 {if( MAX == "" || MAX < $column ) { MAX=$column }} END {print int(MAX)}' $STATFILE
        ;;
        "avg" )
            $AWK -v column="$CPUTYPE" 'NR>1 { SUM += $column } END {print int(SUM/(NR-1))}' $STATFILE
        ;;
        * )
            $AWK -v column="$CPUTYPE" 'NR>1 { SUM += $column } END {print int(SUM)}' $STATFILE
        ;;
    esac
}

# get_stat_in_bytes
# Report mem, I/O stats.
# REPORT_OPTION
#   -d | -r option for call pidstat
# COLUMN_NUMBER - column number with required value
# AGG - aggregate function
#   min max avg sum
function get_stat_in_bytes () {
    REPORT_OPTION=$1
    COLUMN_NUMBER=$2
    AGG=$3
    NOW=`date +%s`
    LASTMOD=0
    STATFILE=`echo -n ${PROG_NAME} | sed 's/\//_/g'`
    STATFILE=${TMP_TEMPLATE}${STATFILE}.${REPORT_OPTION}.pidstat
    if [ -r $STATFILE ]; then
        LASTMOD=`stat -c "%Y" $STATFILE`
    fi
    let "AGE = $NOW - $LASTMOD"
    if [ $AGE -gt $CACHEAGE ]; then
        $SUDO $PIDSTAT -C $PROG_NAME ${REPORT_OPTION} -p ALL 1 $MAXCOUNT | grep "^Average:" > $STATFILE
    fi
    case "${AGG}" in
        "min" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MIN == "" || MIN > $column ) { MIN=$column }} END {print MIN*1024}' $STATFILE
        ;;
        "max" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 {if( MAX == "" || MAX < $column ) { MAX=$column }} END {print MAX*1024}' $STATFILE
        ;;
        "avg" )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END {print int((SUM*1024)/(NR-1))}' $STATFILE
        ;;
        * )
            $AWK -v column="$COLUMN_NUMBER" 'NR>1 { SUM += $column } END {print int(SUM*1024)}' $STATFILE
        ;;
    esac
}

# get_count
# Report the count of running programs
function get_count () {
    # -1 call of this program
    # -2 grep
    # -3 expr
    expr `ps ax | grep "$PROG_NAME" | wc -l` - 3
}

# LLD mode
# In LLD mode, the script returns a list of names of all running processes.
function lld () {
    types_stat="vsz rss ioread iowrite cpu_user cpu_system"
    aggregate_functions="min max avg sum"
    echo {"data":[
    for program in `ps ax -o comm=Command | tail -n +2 | sort | uniq` ; do
        for stat in $types_stat ; do
            for func in $aggregate_functions ; do
                echo {\"{#PROGNAME}\":\"$program\", \"{#STATSNAME}\":\"$stat\", \"{#AGG_FUNC}\":\"$func\"},
            done
        done
        echo {\"{#PROGNAME}\":\"$program\", \"{#STATSNAME}\":\"count\", \"{#AGG_FUNC}\":\"count\"},
    done
    echo ]}
}

case "${RESOURCE}" in
    "vsz" )
        get_stat_in_bytes -r 6 $AGG_TYPE
    ;;
    "rss" )
        get_stat_in_bytes -r 7 $AGG_TYPE
    ;;
    "ioread" )
        get_stat_in_bytes -d 4 $AGG_TYPE
    ;;
    "iowrite" )
        get_stat_in_bytes -d 5 $AGG_TYPE
    ;;
    "cpu_user" )
        get_cpustat 4 $AGG_TYPE
    ;;
    "cpu_system" )
        get_cpustat 5 $AGG_TYPE
    ;;
    "count" )
        get_count
    ;;
    "lld" )
        #comment out next line if you don't need LLD mode
        lld
    ;;
    * )
        echo -1
        exit 1
    ;;
esac
