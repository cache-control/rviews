#! /bin/bash

APPNAME=${BASH_SOURCE##*/}
WORKDIR=/dev/shm
CURL=(
    curl 
    --silent
    --compressed
)

usage() {
cat <<__EOF__
usage:  $APPNAME [-h] [OPTION]* <ip> <router>

        OPTION:

        -h              this help
        -l              list router (i.e. collector)
        -R              raw output

        ip              destination ip address
        router          router to query

        ex:

        $APPNAME -l
        $APPNAME 142.250.189.14 route-views.sfmix.routeviews.org
        $APPNAME 142.250.189.14 route-views.sydney

__EOF__

    exit 0
}

listCollectors() {
    local rawCollectors=$WORKDIR/.$APPNAME.collectors.html
    local csvCollectors=$rawCollectors.csv
    local outputType=--c2p

    [ -n "$raw" ] && outputType=--csv

    # cache HTML collectors page
    [ ! -s $rawCollectors ] && {
        "${CURL[@]}" -o $rawCollectors https://www.routeviews.org/routeviews/collectors/
    }

    # extract tables from HTML collectors page
    [ ! -s $csvCollectors ] && {
        cat $rawCollectors \
            | sed 's,</td>,|</td>,g' \
            | html2text -width 20000 -style pretty \
            | sed -n -e /routeviews.org/p -e /Applications/q \
            | sed -r -e '/\|$/!{N; s/\n//;}' -e 's/ +/ /g' -e 's/\| /|/g' -e 's/\|$//' \
            > $csvCollectors
    }

    # mash two distinct tables into one
    {
        grep -Pv ^route-views $csvCollectors \
            | mlr --csv --ifs='|' --hi --ho cat

        grep -P ^route-views $csvCollectors \
            | mlr --csv --ifs='|' --hi --ho \
                label Collector,Proto,Location \
                then put '$IX="unknown"' \
                then cut -o -f IX,Location,Proto,Collector

    } | mlr $outputType label IX,Location,Proto,Collector
}

getRoute() {
    local addr=$1
    local router=${2%%.routeviews.org}+
    local query=bgp
    local protocol=IPv4
    local url=https://lg.routeviews.org/lg/
    local payload=

    payload+="query=$query"
    payload+="&protocol=$protocol"
    payload+="&addr=$addr"
    payload+="&router=$router"

    "${CURL[@]}" $url --data-raw "$payload" \
        | html2text -width 20000 -style pretty
}

showBestRoute() {
    [ -n "$raw" ] \
        && cat \
        || sed -nre '/^\s+[0-9]/,/^\s+Last/{ :a;N;/Last/!ba;/ best /p}' -e '/BGP routing table/p'
}

while getopts hlR c
do
    case $c in
        b)      start_time="$OPTARG";;
        l)      listCollectors; exit 0;;
        R)      raw=true;;
        *)      usage;;
    esac
done
shift $((OPTIND - 1))

[ $# -ne 2 ] && usage

addr=$1
router=$2

getRoute $addr $router | showBestRoute
