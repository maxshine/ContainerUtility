Container Utility Set
=======

Container is a hot spot in nowadays IT world. However, to live a good life with containers requires many homemade tools, which act just like TV, PS4, air conditioner in your house and et al.

Therefore, this project is initialed to host a set of utility I developed to facilitate everyone to begin their tours smoothly.


1. dm_mount.sh
This tool is used to manipulate docker container RW layer easily with device mapper driver. As we all know, the default behavior of docker suite will remove virtual block driver when the container is down and it can not be accessed unless you let container up. The tool would help you do this even if the container is dead, as long as its RW layer is still there.

For usage, please just issue the command `dm_tool.sh` to view.

