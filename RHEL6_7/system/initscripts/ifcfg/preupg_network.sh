#!/bin/bash

orig_name_base="eth"
new_name_base="net"
conf_dir='/etc/sysconfig/network-scripts'
temp_conf_dir='/root/preupgrade/dirtyconf/etc/sysconfig/network-configuration_fixed/'
udev_command='/sbin/udevadm info -a  -p'
dev_path='/sys/class/net'
cat /dev/null > udev_temp 

if ls "$dev_path" | grep -q "rename[0-9]+$";then
    exit 1
fi

if grep -q "^MACADDR=" "$conf_dir"/ifcfg-*;then
    exit 2
fi

if ! [ -e "$temp_conf_dir" ];then
    mkdir -p "$temp_conf_dir"
fi

for orig_full_name in "$dev_path"/*/device
do
    orig_full_name="${orig_full_name#*net/}"
    orig_full_name="${orig_full_name%/*}"
    orig_conf_file="${conf_dir}/ifcfg-${orig_full_name}"
    mac_rule=$($udev_command "${dev_path}/${orig_full_name}" | egrep "ATTR\{address\}")
    mac=$(echo "$mac_rule" | awk -F'==' '{print $2}')
    dev_type_rule=$($udev_command "${dev_path}/${orig_full_name}" | egrep "ATTR\{type\}")

    if echo $orig_full_name |egrep -q "$orig_name_base[0-9]+$";then
        index=`echo $orig_full_name |sed -e "s/^$orig_name_base//g"`
        new_full_name="${new_name_base}$index"
    fi

    if [ -f "$orig_conf_file" ];then
        if [ -n "$new_full_name" ];then
           new_conf_file="${temp_conf_dir}/ifcfg-${new_full_name}" 
           cp -p "$orig_conf_file" "$new_conf_file"
           sed -i "s/^HWADDR=.*/HWADDR=$mac/g" "$new_conf_file"
           sed -r -i "s/^NAME=.*|^DEVICE=.*/DEVICE=$new_full_name/g" "$new_conf_file"
        fi
    fi

    echo -e "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", $mac_rule, $dev_type_rule, KERNEL==\"${orig_name_base}*\", NAME=\"$new_full_name\"\n" >> udev_temp

done

mv udev_temp "$temp_conf_dir"

echo "To rename the interfaces to persistent user defined names, replace ifcfg-eth* files in $conf_dir with ifcfg-net* files from $temp_conf_dir \
      and copy udev_temp from $temp_conf_dir to /etc/udev/rules.d/70-persistent-net.rules" >> solution.txt

