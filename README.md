Container Utility Set
=======

Container is a hot spot in nowadays IT world. However, to live a good life with containers requires many homemade tools, which act just like TV, PS4, air conditioner in your house and et al.

Therefore, this project is initialed to host a set of utility I developed to facilitate everyone to begin their tours smoothly.


1. dm_mount.sh
This tool is used to manipulate docker container RW layer easily with device mapper driver. As we all know, the default behavior of docker suite will remove virtual block driver when the container is down and it can not be accessed unless you let container up. The tool would help you do this even if the container is dead, as long as its RW layer is still there.

For usage, please just issue the command `dm_mount.sh` to view.

2. dm_size.sh
This tool is to enlarge container RW layer size. By default it is 10G when container is created with defaults. It support to update the size when container is running or existed

For usage please just issue the command `dm_size.sh` to view.

3. dm_usage.sh
This tool is to print out the usage information of devicemapper devices used by specific container and the device pool used by docker daemon. Pleaes note the information is viewed from device perspective. So, it may be slightly different from the statistics from filesystem view.

For usage please just issue the command `dm_usage.sh` to view.