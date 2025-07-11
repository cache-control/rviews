#! /bin/bash

APPNAME=${BASH_SOURCE##*/}
WORKDIR=/dev/shm
CURL=(
    curl 
    --silent
    --compressed
)

begin_time='1 hour ago'
end_time='15 minutes ago'
protocol=IPv4

usage() {
cat <<__EOF__
usage:  $APPNAME [-h] [OPTION]* <router> [addr]

        OPTION:

        -h              this help
        -6              use IPv6 (default: $protocol)
        -b              begin time (default: $begin_time)
        -e              end time (default: $end_time)
        -l              list routers (i.e. collectors)
        -L              list routers with extra details
        -R              raw output

        router          router to query (ex: route-views.chicago[.routeviews.org])
        addr            destination ip address or AS regex

        ex:

        $APPNAME -l
        $APPNAME route-views.sydney 142.250.189.14  # find best route
        $APPNAME -b '30 minutes ago' route-views3   # retrieve updates
        $APPNAME frr _15169$                        # get routes for AS

__EOF__

    exit 0
}

listCollectors() {
    local rawCollectors=$WORKDIR/.$APPNAME.collectors-$(date +%Y%m%d).html
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

listCollectorsWithDetails() {
    local rawCollectors=$WORKDIR/.$APPNAME.collectors-details-$(date +%Y%m%d).html
    local outputType=--c2p

    [ -n "$raw" ] && outputType=--csv

    # cache HTML collectors page
    [ ! -s $rawCollectors ] && {
        "${CURL[@]}" -o $rawCollectors https://archive.routeviews.org/peers/peering-status.html
    }

    fgrep .routeviews.org $rawCollectors \
        | mlr --hi $outputType --ifs='|' \
            clean-whitespace \
            then filter 'if ($1 =~ "^([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)") { $col="\1"; $as="\2"; $addr="\3"; $prefixes="\4";}' \
            then cut -o -f col,as,addr,prefixes,2,3,4 \
            then label collector,asnum,address,prefixes,cc,region,asname
}

getRoute() {
    local addr=$1
    local router=${2%%.routeviews.org}+
    local query=bgp
    local protocol=$protocol
    local url=https://lg.routeviews.org/lg/
    local payload=()
    local filter=(
        sed -nr
        -e '/^\s+[0-9]/,/^\s+Last/{ :a;N;/Last/!ba;/ best /p}'
        -e '/BGP routing table/p'
    )

    [[ $addr =~ : ]] && protocol=IPv6
    [[ $addr =~ ^[^:.]+$ ]] && {
        query='bgp regexp'
        raw=true
    }

    [ -n "$raw" ] && filter=(cat)

    payload+=(--data-urlencode "query=$query")
    payload+=(--data-raw "protocol=$protocol")
    payload+=(--data-urlencode "addr=$addr")
    payload+=(--data-raw "router=$router")

    "${CURL[@]}" $url "${payload[@]}" \
        | html2text -width 20000 -style pretty \
        | "${filter[@]}"
}

getUpdates() {
    local router=${1%%.routeviews.org}
    local begin_epoch=$( date -ud "$begin_time" +%s)
    local end_epoch=$( date -ud "$end_time" +%s)
    local interval=900
    local begin_block=$(( ($begin_epoch/$interval)*$interval )) #start of 15-minute block
    local end_block=$(( ($end_epoch/$interval)*$interval ))

    for ts in $(seq $begin_block $interval $end_block); do
        local url=$(date -ud @$ts +https://archive.routeviews.org/$router/bgpdata/%Y.%m/UPDATES/updates.%Y%m%d.%H%M.bz2)
        local cachefile=$WORKDIR/.$APPNAME.updates.$router.$ts.bz2

        [ ! -s "$cachefile" ] && {
            "${CURL[@]}" -o $cachefile $url
        }

        if [ -n "$raw" ]; then
            bzip2 -dc $cachefile
        else
            bzip2 -dc $cachefile | bgpdump -v -m -
        fi
    done
}

while getopts h6b:e:lLR c
do
    case $c in
        6)      protocol=IPv6;;
        b)      begin_time="$OPTARG";;
        e)      end_time="$OPTARG";;
        l)      listCollectors; exit 0;;
        L)      listCollectorsWithDetails; exit 0;;
        R)      raw=true;;
        *)      usage;;
    esac
done
shift $((OPTIND - 1))

[ $# -eq 0 ] && usage

router=$1
addr=$2

action=getUpdates
[ -n "$addr" ] && action=getRoute

case $action in
    getRoute)
        getRoute $addr $router
        ;;

    getUpdates)
        getUpdates $router
        ;;
esac
