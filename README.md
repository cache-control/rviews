# rviews
CLI wrapper for routeviews.org

## Introduction
RouteViews is a project that exposes BGP routes via telnet and
<https://lg.routeviews.org/lg/>. This script is a wrapper around the
latter.

## Requirements
* curl: command line tool for transferring data with URL syntax
  ```sh
  sudo apt install curl
  ```
* html2text: advanced HTML to text converter
  ```sh
  sudo apt install html2text
  ```
* bgpdump: Translate binary zebra/quagga/MRT files into readable output
  ```sh
  sudo apt install bgpdump
  ```
* mlr: name-indexed data processing tool
  ```sh
  sudo apt install miller
  ```

## Help
```sh
usage:  rviews.sh [-h] [OPTION]* <router> [addr]

        OPTION:

        -h              this help
        -6              use IPv6 (default: IPv4)
        -b              begin time (default: 1 hour ago)
        -e              end time (default: 15 minutes ago)
        -l              list routers (i.e. collectors)
        -L              list routers with extra details
        -R              raw output

        router          router to query (ex: route-views.chicago[.routeviews.org])
        addr            destination ip address or AS regex

        ex:

        rviews.sh -l
        rviews.sh route-views.sydney 142.250.189.14  # find best route
        rviews.sh -b '30 minutes ago' route-views3   # retrieve updates
        rviews.sh frr _15169$                        # get routes for AS

```

## Usage

Use `-l` flag to get list of available routers (i.e. collectors).

The first required argument is `router` which is a collector name; it may be
specified with or without the domain `.routeviews.org`. The second
argument, `addr`, is optional.

* If `addr` is omitted: updates are retrieved from `router`
* if `addr` is an IP address: the best route is pulled from `router` for `addr`
* if `addr` is **not** an IP address: execute `bgp regexp` for `addr`

Use `-b` and `-e` flags to specify time window for retrieval of updates.

## Examples

Query a collector for best route to an address.
```sh
$ rviews.sh route-views.sfmix.routeviews.org 142.250.189.14
```
```
  BGP routing table entry for 142.250.189.0/24, version 750982
    34927 15169
      206.197.187.106 (metric 106) from 206.197.187.106 (185.44.83.3)
        Origin IGP, metric 0, valid, external, best (Older Path), rpki validation-state: valid
        Community: 34927:330 34927:359
        Last update: Wed May 14 03:26:16 2025
```

Query collectors in *California* for best route to an address.
```sh
$ rviews.sh -R -l | \
    mlr --csv --ho grep California then cut -f Collector | \
    xargs -I {} rviews.sh {} 142.250.72.142
```
```
  BGP routing table entry for 142.250.72.0/24, version 7454894
    101 15169
      207.231.243.1 from 207.231.243.1 (209.124.190.9)
        Origin IGP, metric 100, valid, external, multipath, best (Older Path), rpki validation-state: valid
        Community: 101:20400 101:22200 101:24100
        Extended Community: RT:101:22200
        Last update: Fri Jun  6 08:59:18 2025
  BGP routing table entry for 142.250.72.0/24, version 448139
    6939 15169
      198.32.176.20 from 198.32.176.20 (216.218.252.221)
        Origin IGP, valid, external, best (AS Path)
        Last update: Sun Dec 22 21:03:41 2024
  BGP routing table entry for 142.250.72.0/24, version 750521
    34927 15169
      206.197.187.106 (metric 106) from 206.197.187.106 (185.44.83.3)
        Origin IGP, metric 0, valid, external, best (Older Path), rpki validation-state: valid
        Community: 34927:330 34927:359
        Last update: Wed May 14 03:26:16 2025
```

Retrieve updates for specific time window
```sh
$ rviews.sh -b '2025-07-01 10:05 GMT' -e '2025-07-01 10:15 GMT' route-views.chicago.routeviews.org | head
```
```
BGP4MP_ET|1751364000.072154|A|208.115.136.67|852|45.172.92.0/22|852 1299 17072 17072 17072 17072 265566|IGP|208.115.136.67|0|20445||NAG||
BGP4MP_ET|1751364000.072399|A|208.115.136.67|852|130.137.86.0/24|852 1299 16509|IGP|208.115.136.67|0|20445||NAG||
BGP4MP_ET|1751364000.077944|A|2001:504:0:4::852:1|852|2a03:eec0:3212::/48|852 3257 1299 22616|IGP|2001:504:0:4::852:1|0|20445||NAG||
BGP4MP_ET|1751364000.091059|A|208.115.136.95|17350|109.65.218.0/24|17350 1299 8551|IGP|208.115.136.95|0|0|1299:5000 17350:5000 17350:5124|NAG|65181 212.179.37.1|
BGP4MP_ET|1751364000.091144|A|208.115.137.200|14630|109.65.218.0/24|14630 1299 8551|IGP|208.115.137.200|0|0|1299:5000 1299:30000 14630:4 14630:5000|NAG|65181 212.179.37.1|
BGP4MP_ET|1751364000.091403|A|2001:504:0:4::3257:1|3257|2804:87bc:dc04::/48|3257 3356 37468 61609|IGP|2001:504:0:4::3257:1|0|0|3257:8223 3257:30046 3257:50002 3257:51100 3257:51101|NAG||
BGP4MP_ET|1751364000.104654|A|208.115.137.69|16552|109.65.218.0/24|16552 1299 8551|IGP|208.115.137.69|0|0|1299:30000 16552:9100 16552:10500 16552:20840 16552:40014|NAG|65181 212.179.37.1|
BGP4MP_ET|1751364000.104846|A|208.115.137.69|16552|116.206.164.0/24|16552 2914 174 17557 24499 135632 135632 135632 135632 135632 135632 135632|IGP|208.115.137.69|0|0|2914:420 2914:1001 2914:2000 2914:3000 16552:9100 16552:10500 16552:20840 16552:40014|NAG||
BGP4MP_ET|1751364000.107627|A|208.115.137.35|8220|109.65.218.0/24|8220 1299 8551|IGP|208.115.137.35|0|0|1299:30000 8220:1299 8220:64006 8220:65001 8220:65250 8220:65400|NAG|65181 212.179.37.1|
BGP4MP_ET|1751364000.180810|A|208.115.136.5|17350|130.137.86.0/24|17350 6453 16509|IGP|208.115.136.5|0|0|6453:5000 17350:5000 17350:5124|NAG||
```
