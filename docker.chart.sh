#!/bin/sh

# docker.chart.sh - netdata charts.d plugin to gather stats on Docker containers
# Mon Apr 11 2016
# Requirements:
#   bash version 4
#   The 'bc' utility must be installed
#   Setup sudoers:
#   netdata	ALL=(ALL)       NOPASSWD: /usr/bin/docker
# Copyright (C) 2016  David Chouinard

################################################################################
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_

# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
docker_update_every=

docker_priority=150000

# _check is called once, to find out if this chart should be enabled or not
docker_check() {

  # Disable the chart if we don't have basic pre-reqs
  test -e /usr/bin/docker || return 1
  test -e /bin/bc || return 1
  /bin/bash --version | head -1 | grep 'version 4.' > /dev/null || return 1

  declare -A -g c_pids
  declare -A -g c_names
  docker_ids="$(sudo /usr/bin/docker ps -q --no-trunc)"
  for id in $docker_ids
    do
      c_pids[$id]=$(sudo /usr/bin/docker inspect -f '{{ .State.Pid }}' $id)
      c_names[$id]=$(sudo /usr/bin/docker inspect -f '{{ .Name }}' $id | sed -e 's@^/@@')
    done

	# this should return:
	#  - 0 to enable the chart
	#  - 1 to disable the chart

	return 0
}

# _create is called once, to create the charts
docker_create() {
# create the charts with dimensions
echo "CHART docker.cpu '' \"Container CPU Stats\" \"milliseconds\" cpu cpu line $[docker_priority + 1] $docker_update_every"
for id in $docker_ids
  do
    echo "DIMENSION ${c_names[$id]} '' incremental 1 1"
  done

echo "CHART docker.mem '' \"Container Memory Stats\" \"megabytes\" memory memory line $[docker_priority + 1] $docker_update_every"
for id in $docker_ids
  do
    echo "DIMENSION ${c_names[$id]} '' absolute 1 1"
  done

echo "CHART docker.io '' \"Container I/O Stats\" \"bytes\" io io line $[docker_priority + 1] $docker_update_every"
for id in $docker_ids
  do
    echo "DIMENSION ${c_names[$id]} '' incremental 1 1"
  done

echo "CHART docker.net '' \"Container Net Stats\" \"bytes\" net net line $[docker_priority + 1] $docker_update_every"
for id in $docker_ids
  do
    echo "DIMENSION ${c_names[$id]} '' incremental 1 1"
  done

return 0
}

# _update is called continiously, to collect the values
docker_update() {

# the first argument to this function is the microseconds since last update
# pass this parameter to the BEGIN statement (see bellow).

# do all the work to collect / calculate the values
# for each dimension
# remember: KEEP IT SIMPLE AND SHORT

echo "BEGIN docker.cpu $1"
for id in $docker_ids
  do
    cpu_nano=$(cat /sys/fs/cgroup/cpuacct/docker/$id/cpuacct.usage)
    cpu_val=$(echo "scale=2; $cpu_nano / 1000000" | bc)
    echo "SET ${c_names[$id]} = $cpu_val"
  done
echo "END"

echo "BEGIN docker.mem $1"
for id in $docker_ids
  do
    mem_bytes=$(cat /sys/fs/cgroup/memory/docker/$id/memory.usage_in_bytes)
    mem_val=$(echo "scale=2; $mem_bytes / 1000000" | bc)
    echo "SET ${c_names[$id]} = $mem_val"
  done
echo "END"

echo "BEGIN docker.io $1"
for id in $docker_ids
  do
    io_val=$(tail -1 /sys/fs/cgroup/blkio/docker/$id/blkio.throttle.io_service_bytes | cut -d ' ' -f 2)
    echo "SET ${c_names[$id]} = $io_val"
  done
echo "END"

echo "BEGIN docker.net $1"
for id in $docker_ids
  do
    container_pid=${c_pids[$id]}
    net_data=$(grep eth0 /proc/$container_pid/net/dev)
    bytes_in=$(echo $net_data|cut -d ' ' -f 2)
    bytes_out=$(echo $net_data|cut -d ' ' -f 10)
    net_val=$((bytes_in + bytes_out))
    echo "SET ${c_names[$id]} = $net_val"
  done
echo "END"

return 0
}
