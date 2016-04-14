# docker-netdata-plugin
charts.d plugin for [netdata](https://github.com/firehol/netdata) that will graph Docker container stats

![netdata docker screenshot](netdata-docker.png?raw=true)

## Install
Place docker.chart.sh inside the charts.d directory.

For example: /opt/netdata/usr/libexec/netdata/charts.d/docker.chart.sh 

Add section to var menuData = ... inside index.html

        'docker': {
                title: 'Docker',
                info: undefined
         },

Restart netdata

## Requirements
/usr/bin/docker and /bin/bc

bash version 4

Sudo entry for the user that runs netdata:

netdata       ALL=(ALL)       NOPASSWD: /usr/bin/docker

