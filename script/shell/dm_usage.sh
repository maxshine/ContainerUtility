/****************************************************************************
 * Copyright (c) 2017-now                                                   *
 * This software is subjected to Apache License Version 2.0, January 2004   *
 * http://www.apache.org/licenses/                                          *
 * Permission is hereby granted, free of charge, to any person obtaining a  *
 * copy of this software and associated documentation files (the            *
 * "Software"), to deal in the Software without restriction, including      *
 * without limitation the rights to use, copy, modify, merge, publish,      *
 * distribute, distribute with modifications, sublicense, and/or sell       *
 * copies of the Software, and to permit persons to whom the Software is    *
 * furnished to do so, subject to the following conditions:                 *
 *                                                                          *
 * The above copyright notice and this permission notice shall be included  *
 * in all copies or substantial portions of the Software.                   *
 *                                                                          *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS  *
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF               *
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.   *
 * IN NO EVENT SHALL THE ABOVE COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,   *
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR    *
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR    *
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.                               *
 *                                                                          *
 * Except as contained in this notice, the name(s) of the above copyright   *
 * holders shall not be used in advertising or otherwise to promote the     *
 * sale, use or other dealings in this Software without prior written       *
 * authorization.                                                           *
 ****************************************************************************/

/****************************************************************************
 *  Author: Yang, Gao  <maxshine@gmail.com> 2017-on                         *
 ****************************************************************************/

#!/bin/bash
CURRENTDIR=`cd $(dirname $0);pwd`

function usage()
{
    echo "$0 <container name> "
    echo "Example: $0 bvt_web_1"
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

function calc_percentage()
{
    result=`echo "scale=4;$1 / $2 * 100" | bc -l`
    echo $result
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

function check_device_status()
{
    # return code : 0 - exist; 1 - no exist
    device_name=`get_device_name $1`
    ls /dev/mapper/$device_name 2>$1 >/dev/null
    return $?
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

function get_pool_device_name()
{
    echo `ls /dev/mapper/ | grep pool`
}

function get_minor_dev_no()
{
    prefix=`get_device_name_prefix`
    real_name=`readlink /dev/mapper/$prefix-pool | cut -d '/' -f 2`
    minor_no=`ls -l /dev/$real_name | cut -d ',' -f 2 | cut -d ' ' -f 2`
    echo $minor_no
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

function get_pool_usage()
{
    params=`dmsetup status $(get_pool_device_name)`
    exit_on_error "Error while retrieve device information"
    meta_used_raw=`echo $params | cut -d ' ' -f 5 | cut -d '/' -f 1`
    meta_total_raw=`echo $params | cut -d ' ' -f 5 | cut -d '/' -f 2`
    data_used_raw=`echo $params | cut -d ' ' -f 6 | cut -d '/' -f 1`
    data_total_raw=`echo $params | cut -d ' ' -f 6 | cut -d '/' -f 2`

    sector_in_block=`expr $(echo $params | cut -d ' ' -f 2) / $data_total_raw`
    bytes_in_block=`expr $sector_in_block \* 512`

    meta_used=`expr $meta_used_raw \* $bytes_in_block`
    meta_total=`expr $meta_total_raw \* $bytes_in_block`
    data_used=`expr $data_used_raw \* $bytes_in_block`
    data_total=`expr $data_total_raw \* $bytes_in_block`
    echo "Pool Usage - Meta : `calc_percentage $meta_used $meta_total`% ($meta_total) Data : `calc_percentage $data_used $data_total`% ($data_total)"
}

function get_container_usage()
{
    device_name=`get_device_name $1`
    params=`dmsetup status $device_name`
    exit_on_error "Error : Fail to retrieve device information for $1"
    size_total=`echo $params | cut -d ' ' -f 5`
    size_used=`echo $params | cut -d ' ' -f 4`
    echo "Container Usage $1 - `calc_percentage $size_used $size_total`% (`expr $size_total \* 512`)"
}


case $1 in
    "all")
	if [ $# -ne 1 ]
	then
	    usage
	fi
	check_daemon
	for i in `docker container ls -a -q`
	do
	    check_container_existence $i
	    check_device_status $i
	    if [ $? -eq 0 ] 
	    then
		get_container_usage $i
	    else
		
		activate_device $i
		get_container_usage $i
		deactivate_device $i
	    fi	    
	done	
	;;
    *)
	if [ $# -ne 1 ]
	then
	    usage
	fi

	check_daemon
	check_container_existence $1
	check_device_status $1
	if [ $? -eq 0 ] 
	then
	    get_container_usage $1
	else

	    activate_device $1
	    get_container_usage $1
	    deactivate_device $1
	fi
	;;
esac
get_pool_usage
