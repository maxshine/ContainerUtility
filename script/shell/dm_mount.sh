#!/bin/bash

#/****************************************************************************
# * Copyright (c) 2017-now                                                   *
# * This software is subjected to Apache License Version 2.0, January 2004   *
# * http://www.apache.org/licenses/                                          *
# * Permission is hereby granted, free of charge, to any person obtaining a  *
# * copy of this software and associated documentation files (the            *
# * "Software"), to deal in the Software without restriction, including      *
# * without limitation the rights to use, copy, modify, merge, publish,      *
# * distribute, distribute with modifications, sublicense, and/or sell       *
# * copies of the Software, and to permit persons to whom the Software is    *
# * furnished to do so, subject to the following conditions:                 *
# *                                                                          *
# * The above copyright notice and this permission notice shall be included  *
# * in all copies or substantial portions of the Software.                   *
# *                                                                          *
# * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS  *
# * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF               *
# * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.   *
# * IN NO EVENT SHALL THE ABOVE COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,   *
# * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR    *
# * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR    *
# * THE USE OR OTHER DEALINGS IN THE SOFTWARE.                               *
# *                                                                          *
# * Except as contained in this notice, the name(s) of the above copyright   *
# * holders shall not be used in advertising or otherwise to promote the     *
# * sale, use or other dealings in this Software without prior written       *
# * authorization.                                                           *
# ****************************************************************************/

# /****************************************************************************
# *  Author: Yang, Gao  <maxshine@gmail.com> 2017-on                         *
# ****************************************************************************/

CURRENTDIR=`cd $(dirname $0);pwd`

function usage()
{
    echo "$0 <action> <container name> <target path>"
    echo "action could be enable or disable"
    echo "Example: $0 enable bvt_web_1 /root/test"
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
    temp=`docker info | grep 'Storage Driver' | cut -d ':' -f 3`
    exit_on_error "Docker Daemon is not at compatible level !"
    if [ $temp != "devicemapper" ]
    then
	echo "Docker is not using desired devicemapper driver, exiting..."
	exit 1
    fi
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
    driver_type=`get_driver_type $1`
    if [ $driver_type != 'devicemapper' ]
    then
        exit_on_error "This container DOES NOT USE device-mapper driver ! Nothing to do"
    fi

#    dmsetup info $device_name  2>&1 >/dev/null
    ls /dev/mapper/$device_name 2>$1 >/dev/null
    exit_on_error "Stroage Device of $1 DOES NOT EXIST !"
}

function check_device_noexistence()
{
    device_name=`get_device_name $1`
    if [ $driver_type != 'devicemapper' ]
    then
        exit_on_error "This container DOES NOT USE device-mapper driver ! Nothing to do"
    fi
    ls /dev/mapper/$device_name 2>$1 >/dev/null
#    dmsetup info $device_name  2>&1 >/dev/null
    exit_on_success "Stroage Device of $1 Already EXISTS !"
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

function mount_target()
{
    dev_name=`get_device_name $1`
    dev_id=`get_device_id $1`
    if [ ! -d $2 ]
    then
	   mkdir $2
    fi
    exit_on_error "Create $2 fails !"
    mount /dev/mapper/$dev_name $2
    echo_on_error "Mount /dev/mapper/$dev_name onto $2 fail ! Clearing"
}

function umount_target()
{
    dev_name=`get_device_name $1`
    dev_id=`get_device_id $1`
    umount /dev/mapper/$dev_name
    exit_on_error "Unmount $1 fail !"
}

function activate_device()
{
    dev_name=`get_device_name $1`
    dev_id=`get_device_id $1`
    dev_size=`get_device_size $1`
    major=`get_major_dev_no`
    minor=`get_minor_dev_no`
    table="0 $dev_size thin $major:$minor $dev_id"
#    echo $table
    dmsetup create "$dev_name" --addnodeoncreate --table "$table"
    exit_on_error "Erro while activating dm device"
}

function deactivate_device()
{
    dev_name=`get_device_name $1`
    dev_id=`get_device_id $1`
    dev_size=`get_device_size $1`
    major=`get_major_dev_no`
    minor=`get_minor_dev_no`
    dmsetup remove $dev_name
    exit_on_error "Erro while deactivating dm device"
}


case $1 in
    "enable")
	if [ $# -ne 3 ]
	then
	    usage
	fi
	check_daemon
	check_container_existence $2
	check_device_noexistence $2
	activate_device $2
	mount_target $2 $3
	;;
    "disable")
	if [ $# -ne 3 ]
	then
	    usage
	fi

	check_daemon
	check_container_existence $2
	check_device_existence $2
	umount $3
	deactivate_device $2
	;;
    *)
	usage
	;;
esac
