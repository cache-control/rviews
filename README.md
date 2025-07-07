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
* mlr: name-indexed data processing tool
  ```sh
  sudo apt install miller
  ```

## Usage
```sh
$ rviews.sh 
usage:  rviews.sh [-h] [OPTION]* <ip> <router>

        OPTION:

        -h              this help
        -l              list router (i.e. collector)
        -R              raw output

        ip              destination ip address
        router          router to query

        ex:

        rviews.sh 142.250.189.14 route-views.sfmix.routeviews.org
        rviews.sh 142.250.189.14 route-views.sydney

```

## Examples

Query a collector for best route to an address.
```sh
$ rviews.sh 142.250.189.14 route-views.sfmix.routeviews.org
  BGP routing table entry for 142.250.189.0/24, version 750982
    34927 15169
      206.197.187.106 (metric 106) from 206.197.187.106 (185.44.83.3)
        Origin IGP, metric 0, valid, external, best (Older Path), rpki validation-state: valid
        Community: 34927:330 34927:359
        Last update: Wed May 14 03:26:17 2025
```

Query collectors in *California* for best route to an address.
```sh
$ rviews.sh -R -l | mlr --csv --ho grep California then cut -f Collector | xargs -I {} rviews.sh 142.250.72.142 {}
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
        Last update: Sun Dec 22 21:03:42 2024
  BGP routing table entry for 142.250.72.0/24, version 750521
    34927 15169
      206.197.187.106 (metric 106) from 206.197.187.106 (185.44.83.3)
        Origin IGP, metric 0, valid, external, best (Older Path), rpki validation-state: valid
        Community: 34927:330 34927:359
        Last update: Wed May 14 03:26:17 2025
```
