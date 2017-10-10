#!/bin/bash
CURRENTDIR=`cd $(dirname $0);pwd`

function usage()
{
    echo "$0 <container name> <size in bytes>"
    echo "Warn: new size must not be less than original"
    echo "Example: $0 bvt_web_1 10737418240"
}

function exit_on_error()
{
    if [ $? -ne 0 ]
    then
	echo $1
	exit 1
    fi

}

function exit_on_success()
{
    if [ $? -eq 0 ]
    then
	echo $1
	exit 0
    fi

}

function echo_on_error()
{
    if [ $? -ne 0 ]
    then
	echo $1
    fi

}

function echo_on_success()
{
    if [ $? -eq 0 ]
    then
	echo $1
    fi

}

function check_container_existence()
{
    docker inspect $1 2>&1 >/dev/null
    exit_on_error "Container $1 DOSE NOT EXIST !"
}

function check_daemon()
{
    docker container --help $1 2>&1 >/dev/null
    exit_on_error "Docker Daemon is not available !"
}

function get_container_status()
{
    echo `docker inspect --format '{{.State.Status}}' bvt_web_1`
}

function get_driver_type()
{
    echo  `docker inspect --format '{{.GraphDriver.Name}}' $1`
}

function get_device_id()
{
    echo `docker inspect --format '{{.GraphDriver.Data.DeviceId}}' $1`
}

function get_device_name()
{
    echo `docker inspect --format '{{.GraphDriver.Data.DeviceName}}' $1`
}

function get_device_size()
{
    bytes=`docker inspect --format '{{.GraphDriver.Data.DeviceSize}}' $1`
    echo `expr $bytes '/' 512`
}

function check_device_existence()
{
    device_name=`get_device_name $1`

#    dmsetup info $device_name  2>&1 >/dev/null
    ls /dev/mapper/$device_name 2>$1 >/dev/null
    exit_on_error "Stroage Device of $1 DOES NOT EXIST !"
}

function check_device_noexistence()
{
    device_name=`get_device_name $1`
    ls /dev/mapper/$device_name 2>$1 >/dev/null
#    dmsetup info $device_name  2>&1 >/dev/null
    exit_on_success "Stroage Device of $1 DOES EXIST !"
}

function get_major_dev_no()
{
    tmp=`awk '{if($2=="device-mapper") {print $1}}' /proc/devices`
    test ${#tmp} != 0
    exit_on_error "Device Mapper module is not loaded !"
    echo $tmp
}

function get_device_name_prefix()
{
    echo `ls /dev/mapper/ | grep pool | cut -d '-' -f 1-3`
}

function get_minor_dev_no()
{
    prefix=`get_device_name_prefix`
    real_name=`readlink /dev/mapper/$prefix-pool | cut -d '/' -f 2`
    minor_no=`ls -l /dev/$real_name | cut -d ',' -f 2 | cut -d ' ' -f 2`
    echo $minor_no
}

function get_thin_pool_size()
{
    dev_name=`get_device_name $1`
    id=`echo $dev_name | cut -d '-' -f 4`
    pool_name=${dev_name/$id/pool}
    echo `dmsetup table $pool_name | cut -d ' ' -f 2`
}

function change_container_size_offline()
{
    id=`echo $(get_device_name $1) | cut -d '-' -f 4`
    dst_file=/var/lib/docker/devicemapper/metadata/$id
    cp -f $dst_file /tmp/
    exit_on_error "Fail to read container metadata"
    sed -i -e "s/\"size\":[0-9]*/\"size\":$2/" /tmp/$id
    exit_on_error "Fail to update container offline size"
    cp -f /tmp/$id /var/lib/docker/devicemapper/metadata/
    exit_on_error "Fail to update container metadata"
}

function change_container_size_online()
{
    dev_name=`get_device_name $1`
    exit_on_error "Fail to retrieve device name for container $1"
    old_table=`dmsetup table $dev_name`
    echo $old_table
    exit_on_error "Fail to read exsiting table for $dev_name"
    new_table=`echo $old_table | sed -n -E -e s/.*\(thin.*\)/0\ $2\ \\\\1/p`
    echo $new_table
    dmsetup load $dev_name --table "$new_table"
    exit_on_error "Fail to update online table for device $dev_name"
}

if [ $# -ne 2 ]
then
    usage
fi

container_name=$1
size_byte=$2
size=`expr $size_byte / 512`
pool_size=`get_thin_pool_size $container_name`

if [ $size -ge $pool_size ]
then
    echo "Error: device size $size must be less than pool size $pool_size"
    exit 1
fi

check_daemon
check_container_existence $container_name
status=`get_container_status $container_name`

if [ x${status}x == xrunningx ]
then
    change_container_size_online $container_name $size
    change_container_size_offline $container_name $size
elif [ x${status}x == xexitedx ]
then
    change_container_size_offline $container_name $size
fi
