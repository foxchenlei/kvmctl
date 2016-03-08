#!/bin/bash
#author:Fox Chan
#Email :chenlei.emar.com
#version 0.2
IMAGEDIR="/var/lib/libvirt/images"
XMLDIR="/etc/libvirt/qemu"
do_help() 
{ 
    PROGRAM_NAME=`basename $0` 
    echo "Usage:"
    echo "$PROGRAM_NAME (create|delete)"
    echo "$PROGRAM_NAME (--help|--list|--show|--all)"
} 
if [ $# -eq 0 ]; then
    do_help 
    exit 1
fi 
if [ "$1" == "--help" ]; then 
    do_help 
    exit 0
fi 
if [ "$1" == "--list" ]; then 
    virsh list
    exit 0
fi 
if [ "$1" == "--show" ]; then 
     ps -ef | awk -v format="%-19s %-7s %-7s %s\n" ' BEGIN {printf(format,"KVM GUEST", "PID", "STIME", "TIME")}/kvm -name/&&!/awk/ { printf(format, $10, $2, $5, $7)}'
    exit 0
fi 
if [ "$1" == "--all" ]; then
    virsh list --all
    exit 0
fi 
###########check system basic information################
MAXCPU=`cat /proc/cpuinfo |grep processor|wc -l`
MAXMEM=`free -g|grep Mem|awk '{print $2}'`

if [ "$1" == "create" ]; then
echo -n -e "\033[32mPlease input hostname : \033[0m"
read hostname
echo -n -e "\033[32mPlease input cpu numbers (eq 1-"$MAXCPU") : \033[0m"
read cpu
echo -e "\033[32mMemory info:\033[0m"
free -h|grep Mem|awk -v format="%-7s %-7s %s\n" ' BEGIN {printf(format,"Total", "USED", "FREE")}{ printf(format,$2,$3,$4)}' 
echo -n -e "\033[32mPlease input memory (eq 1-"$MAXMEM") : \033[0m"
read mem
echo ""
echo -e "\033[31mWARINGING: The default diskspace only have 50G.YOU CAN'T CHOOSE OTHERS!!!\033[0m"
echo ""
echo -n -e "\033[32mPlease input eth0 IP address:\033[0m"
read out
echo -n -e "\033[32mPlease input eth0 IP netmask:\033[0m"
read mask
echo -n -e "\033[32mPlease input eth0 IP gateway:\033[0m"
read gateway
if [ "$out" == "" ]; then
echo "eth0 is null."
else
sed -i "s/IPADDR=.*/IPADDR="$out"/g" $IMAGEDIR/ifcfg-eth0
sed -i "s/NETMASK=.*/NETMASK="$mask"/g" $IMAGEDIR/ifcfg-eth0
sed -i "s/GATEWAY=.*/GATEWAY="$gateway"/g" $IMAGEDIR/ifcfg-eth0
fi
echo ""
echo -n -e "\033[32mPlease input eth1 IP address:\033[0m"
read in
echo -n -e "\033[32mPlease input eth1 IP netmask:\033[0m"
read mask
echo -n -e "\033[32mPlease input eth1 IP gateway:\033[0m"
read gateway
if [ "$in" == "" ]; then
echo "eth1 is null."
else
sed -i "s/IPADDR=.*/IPADDR="$in"/g" $IMAGEDIR/ifcfg-eth1
sed -i "s/NETMASK=.*/NETMASK="$mask"/g" $IMAGEDIR/ifcfg-eth1
sed -i "s/GATEWAY=.*/GATEWAY="$gateway"/g" $IMAGEDIR/ifcfg-eth1
fi
echo ""
echo -e "\033[32mThere are your kvm settings. 
                 HOSTNAME   : kvm_$hostname
                 CPU CORE   : $cpu.
                 MEMORY     : "$mem"G.
                 DISKSPACE  : 50G
                 OS         : Centos6.7_64.
                 ETH0       : $out
                 ETH1       : $in\033[0m"
else
        echo "wrong command! Please --help!!!"
        exit 1
fi
echo -n -e "Please confirm. input (y or n) :"
read word
if [ "$word" == "y" ]; then
cp $IMAGEDIR/centos6_7baseimg.qcow2 $IMAGEDIR/kvm_"$hostname".qcow2
cp $XMLDIR/centos6_7baseimg.xml $XMLDIR/kvm_"$hostname".xml
sed -i "s/centos6_7baseimg/kvm_"$hostname"/g" $XMLDIR/kvm_"$hostname".xml
#################cpu,memory################################
sed -i "s/1048576/"$mem"0248576/" $XMLDIR/kvm_"$hostname".xml
sed -i "/vcpu/s/2/$cpu/" $XMLDIR/kvm_"$hostname".xml
#################uuid######################################
UUID=`uuidgen`
sed -i "/<memory/i<uuid>$UUID</uuid>" $XMLDIR/kvm_"$hostname".xml
#################create mac address######################################
MAC1=`echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"'|awk -F "[" '{print $1}'`
sed -i "/<source bridge='br0'/i<mac address='$MAC1'/>" $XMLDIR/kvm_"$hostname".xml
MAC2=`echo -n 52:54:00; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"'|awk -F "[" '{print $1}'`
sed -i "/<source bridge='br1'/i<mac address='$MAC2'/>" $XMLDIR/kvm_"$hostname".xml

virsh define $XMLDIR/kvm_"$hostname".xml >/root/kvminstall.log 2>&1 

sed -i "s/HOSTNAME=.*/HOSTNAME=kvm_"$hostname"/g" /var/lib/libvirt/images/network
###########################must : yum install libguestfs-tools#########################
virt-copy-in -d kvm_$hostname /var/lib/libvirt/images/network /etc/sysconfig/
if [ -n "$out" ];then
virt-copy-in -d kvm_$hostname /var/lib/libvirt/images/ifcfg-eth0 /etc/sysconfig/network-scripts/
fi
if [ -n "$in" ];then
virt-copy-in -d kvm_$hostname /var/lib/libvirt/images/ifcfg-eth1 /etc/sysconfig/network-scripts/
fi

virsh list --all|grep kvm_
echo -e "\033[32m
         hostname :kvm_"$hostname"
         username :root 
         Password :0000001234\033[0m"
else  [ "$word" == "n" ]
      exit 1
fi
