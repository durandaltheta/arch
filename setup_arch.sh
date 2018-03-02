#!/bin/bash 

USAGE( )
{
    echo "$0 valid arguments"
    echo "   -s|--setup [hard drive to install to]: setup drive and install basic arch linux packages."
    echo "          This must be run from the Arch install iso level."
    echo "   --region_city [Region/City]: Example \"America/Detroit\" (required for --setup)"
    echo "   -r|--root_pass [root password]: set the root password (required for --setup)"
    echo "   -u|--user [username]"
    echo "   -p|--pass [password]"
    echo "   -i|--interface [network interface]"
    echo "   -v|--vga [intel/amd/nvidia]: install specific graphics drivers"
    echo "   --guest: install virtualbox guest utilities to install a bunch of drivers for a guest Arch VM"
    echo "   -l|--log [log path/name]: set the logfile #CURRENTLY A STUB"
    echo ""
    echo "example usage"
    echo "-------------"
    echo "\tfrom arch linux install iso welcome terminal:"
    echo "\t$ ./setup_arch.sh -s /dev/sda -r [root password]-u duran -p [duran password] --region_city "America/Detroit" -i enp0s3"
    echo "\t"
    echo "\t"


    echo ""
} 

# parse arguments and setup variables
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in 
        -h|--help)
            USAGE
            exit 
            ;;
        -d|--drive) # setup and install to given hard driver
            DRIVE=$2
            EXEC_STR="$EXEC_STR -d $DRIVE" 
            echo "DRIVE:$DRIVE"
            shift 
            ;;
        --region_city) # for setting up user's region/city locale
            REG_CITY=$2
            EXEC_STR="$EXEC_STR --region_city $REG_CITY" 
            shift
            ;;
        -r|--root_pass) # give root password 
            RPASS=$2 
            EXEC_STR="$EXEC_STR -r $RPASS" 
            echo "RPASS:$RPASS"
            shift
            ;;
        -u|--user)
            USER="$2"
            EXEC_STR="$EXEC_STR -u $USER" 
            echo "USER:$USER"
            shift
            ;;
        -p|--pass)
            PASS="$2"
            EXEC_STR="$EXEC_STR -p $PASS" 
            echo "PASS:$PASS"
            shift
            ;;
        -i|--interface)
            INTERFACE="$2"
            EXEC_STR="$EXEC_STR -i $INTERFACE" 
            echo "INTERFACE:$INTERFACE"
            shift
            ;;
        -v|--vga) # set graphics driver
            VGA="$2"
            EXEC_STR="$EXEC_STR -v $VGA"
            echo "VGA:$VGA"
            shift
            ;;
        *)
            echo "Invalid argument:$2"
            USAGE
            exit
            ;;
    esac
    shift
done 


#**************************************************************
# SETUP HARD DRIVE AND INSTALL BASE ARCH
#
timedatectl set-ntp TRUE
echo -e "o\nn\np\n1\n\n\nw" | fdisk $DRIVE #partition hard drive from /dev
PART="$DRIVE""1" # the created partition 
echo "PART:"$PART
mkfs.ext4 "$PART"
mount "$PART" /mnt
pacstrap /mnt base
genfstab -U /mnt >> /mnt/etc/fstab 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "SCRIPT_DIR:"$SCRIPT_DIR
echo "SCRIPT_NAME:"$SCRIPT_NAME
if [ -z "$SCRIPT_DIR" ]; 
then
   echo "No script directory, exitting"
   exit 
fi
cp "$SCRIPT_DIR"/install.sh /mnt
arch-chroot /mnt "$EXEC_STR"
