#!/bin/bash

MSATA_DONGLE_1=/dev/disk/by-path/pci-0000:02:00.0-ata-1
MSATA_DONGLE_2=/dev/disk/by-path/pci-0000:02:00.0-ata-2
MSATA_DONGLE_3=/dev/disk/by-path/pci-0000:02:00.0-ata-3
MSATA_DONGLE_4=/dev/disk/by-path/pci-0000:02:00.0-ata-4

MSATA=/dev/disk/by-path/pci-0000:00:11.0-ata-1

DISKS=($MSATA_DONGLE_1 $MSATA_DONGLE_2 $MSATA_DONGLE_3 $MSATA_DONGLE_4 $MSATA)

DRIVES_MIN="1"
DRIVES_MAX="5"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# ID|name|path
IMAGES_ARRAY=( "1|pfSense 2.5.2 16GB |images/pfsense.2.5.2.zfs.configured.img"
               "2|pfSense 2.5.0 120GB |images/pfsense.2.5.0.zfs.120G.configured.img" 
               "3|pfSense 2.4.5 16GB |images/pfsense.2.4.5-p1.zfs.configured.img" 

               "5|openwrt-test|images/openwrt-x86-64-generic-squashfs-combined.img"

               "10|OPNSense 21.7.1 ZFS 16GB |images/OPNSense.21.7.configured.16GB.ZFS.img"
               "11|OPNSense 21.1 120GB |images/OPNSense.21.1.configured.120GB.img.gz"

               "20|Debian 16GB |images/debian_16GB.img"
               "21|Debian 120GB |images/debian_16GB.img|resize_part2_to_max_hook"

               "30|Ubuntu 20.04.2 LTS 16GB|images/ubuntu-20.04.2-server.configured.img.gz"
               "31|Ubuntu 20.04.2 LTS 12GB |images/ubuntu-20.04.2-server.configured.img.gz|resize_part2_to_max_hook"

               "40|FreeBSD 16GB |images/freeBSD.configured.img.gz"

               "50|IPFire v153 16GB |images/ipfire-2.25.core153.16GB.img.gz"

               "60|OpenWRT 19.7.2 16GB |images/openwrt-19.07.2-x86-64-combined-ext4.img|resize_part2_to_max_hook"
               "61|OpenWRT 19.7.2 120GB |images/openwrt-19.07.2-x86-64-combined-ext4.img|resize_part2_to_max_hook"

               "80|Vyos 1.4 rolling release 16GB|images/vyos-rolling-1.4.16GB.img.gz"

               "90|Centos 8 Stream EnergiCert|images/centos8-EnergiCert.img.gz"

               "99|Clone drive in slot 5 |$MSATA"
)
 

######################################################################################################

function get_disk_size () {
  DISK_PATH=$1

  disk_size=$(parted $DISK_PATH print --machine --script 2>/dev/null | grep "/dev/" | awk -F: '{print $2}')
  # echo "$DISK_PATH $disk_size"
}

######################################################################################################

function make_new_image () {
  echo "Insert the source image into slot 1"
  wait_for_slot_to_be_present $MSATA_DONGLE_1 "1"  

  echo ""
  echo -ne "image name: "
  read IMAGE_NAME
  
  SECONDS=0

  if [[ "$IMAGE_NAME" == *.gz ]]
    then
    echo "The output image will be compressed."
    dd bs=256K status=progress if=$MSATA_DONGLE_1 | gzip -1 > images/$IMAGE_NAME
  else
    echo "The output image won't be compressed."
    dd bs=256K status=progress if=$MSATA_DONGLE_1 of=images/$IMAGE_NAME
  fi

  duration=$SECONDS

  echo "==> Image $IMAGE_NAME creted in $(($duration / 60)) minutes and $(($duration % 60)) seconds"
  beep
}


######################################################################################################

function is_disk_present () {
  DISK=$1
  SLOT_NAME=$2

  if [[ -L "$DISK" ]]
  then
    symlinks -d /dev/disk/by-path/ &>>/dev/null
    disk_size=""
    get_disk_size $DISK
    echo -ne " \e[32m[ slot $SLOT_NAME $disk_size ]\e[0m "
    return 1
  else
    echo -ne " \e[31m[ slot $SLOT_NAME missing ]\e[0m "
    return 0
  fi
}

function get_populated_slots () {
  SLOTS_NEDDED=$1
  READY_COUNT=0

  for ((diskId=0;diskId<$SLOTS_NEDDED;diskId++)) 
  do
    DISK=${DISKS[$diskId]}
    let "slot_number=$diskId+1"
    is_disk_present "$DISK" "$slot_number"
    let "READY_COUNT+=$?"
  done

  return "$READY_COUNT"  # returns 0-4
}



function wait_for_x_slots_to_be_present () {
  SLOTS_NEEDED=$1

  while [[ true ]]
  do
    echo -ne ""\\r
    get_populated_slots $SLOTS_NEEDED
    READY=$?

    if [[ $READY -eq "$SLOTS_NEEDED" ]]
    then
      echo ""
      break;
    fi

    sleep 1;
  done
}


function wait_for_slot_to_be_present () {
  DISK=$1
  SLOT_NAME=$2

  while [[ true ]]
  do
    if [[ -L "$DISK" ]]
    then
      echo -ne " \e[32m[ slot $SLOT_NAME present ]\e[0m "\\r
      return 1
    else
      echo -ne " \e[31m[ slot $SLOT_NAME missing ]\e[0m "\\r
    fi
    sleep 1;
  done
}


function wait_for_x_slots_to_be_empty () {
  EMPTY_SLOTS_NEDDED=$1
  while [[ true ]]
  do
    echo -ne ""\\r
    get_populated_slots $EMPTY_SLOTS_NEDDED
    READY=$?

    if [[ $READY -eq "0" ]]
    then
      echo ""
      break;
    fi

    sleep 1;
  done
}


######################################################################################################

function flash_x_drives () {
  NUMBER_OF_DRIVES=$1
  IMAGE=$2
  HOOK_FUNCTION=$3

  FLASHED_COUNT=0

  echo " Mass flash has been invoked with this image $IMAGE"

  while [ true ]
  do
    beep;

    echo "<==== Insert $NUMBER_OF_DRIVES new mSATA drives into slots 1-$NUMBER_OF_DRIVES"

    wait_for_x_slots_to_be_present $NUMBER_OF_DRIVES

    echo "====> Got $NUMBER_OF_DRIVES new SSDs, Flashing $IMAGE now."

    SECONDS=0

    OF_CMD=" "

    for ((diskId=0;diskId<$NUMBER_OF_DRIVES;diskId++)) 
    do
      DISK_PATH=${DISKS[$diskId]}
      OF_CMD+="of=${DISK_PATH} "
    done

    echo ""
    if [[ "$IMAGE" == *gz ]]
    then
      unpigz -c $IMAGE | dcfldd bs=1M status=progress $OF_CMD; sync;
    else
      dcfldd bs=1M status=on sizeprobe=if statusinterval=100 if=$IMAGE $OF_CMD; sync;
    fi

    if [[ "$(type -t $HOOK_FUNCTION)" ]]
    then 
      for ((diskId=0;diskId<$NUMBER_OF_DRIVES;diskId++)) 
      do
        DISK_PATH=${DISKS[$diskId]}
        $HOOK_FUNCTION $DISK_PATH
      done
    fi    

    duration=$SECONDS

    FLASHED_COUNT=$((FLASHED_COUNT+$NUMBER_OF_DRIVES))
    echo "==> $NUMBER_OF_DRIVES SSDs were flashed in $(($duration / 60)) minutes and $(($duration % 60)) seconds"

    beep 
    beep 
    beep

    echo "====> Batch finished. ${FLASHED_COUNT} were flashed so far "
    echo "====> Remove the mSATA drives from slots 1-$NUMBER_OF_DRIVES"

    wait_for_x_slots_to_be_empty $NUMBER_OF_DRIVES

  done

}


######################################################################################################

function prep_before_duplication () {
  echo " Duplicating drives. Source: slot 5"

  echo "<==== Insert a master drive into slot 5"

  wait_for_slot_to_be_present $MSATA "5"
  echo " [OK] Got the master drive in slot 5"
}


######################################################################################################


function resize_part2_to_max_hook {
  DISK=$1
  DISK_PART2="$1-part2"

  #TODO: wait for $DISK_PART2 to become present

  disk_size=""
  get_disk_size $DISK

  sgdisk $DISK -e

  echo " Resizing the second partition on $DISK partition to $disk_size ..."
  sync;
  parted -s $DISK resizepart 2 $disk_size
  sleep 1
  e2fsck -f $DISK_PART2
  sleep 1
  resize2fs $DISK_PART2
}


function print_images () {
  for image_line in "${IMAGES_ARRAY[@]}" ; do
    IFS='|'; line_split=($image_line); unset IFS;

    ID=${line_split[0]}   
    NAME=${line_split[1]}   
    IPATH=${line_split[2]}   
    HOOK=${line_split[3]}   
    echo -e "$ID\t$NAME\t"
  done
}

function get_image_path () {
  IMAGE_ID=$1

  for image_line in "${IMAGES_ARRAY[@]}" ; do
    IFS='|'; line_split=($image_line); unset IFS;

    ID=${line_split[0]}   
    NAME=${line_split[1]}   
    IPATH=${line_split[2]}   
    if [[ $ID -eq $IMAGE_ID ]]
    then 
      IMAGE_PATH=$IPATH
      break
    fi
  done
}

function get_image_hook () {
  IMAGE_ID=$1

  for image_line in "${IMAGES_ARRAY[@]}" ; do
    IFS='|'; line_split=($image_line); unset IFS;

    ID=${line_split[0]}   
    NAME=${line_split[1]}   
    IPATH=${line_split[2]}   
    HOOK_FUNC=${line_split[3]}   
    if [[ $ID -eq $IMAGE_ID ]]
    then 
      IMAGE_HOOK_FUNCTION=$HOOK_FUNC
      break
    fi
  done
}

function flash_selector () {
  echo "Available images:"
  print_images

  echo -ne "Which OS do you want to flash: "
  read IMAGE_ID
  IMAGE_PATH=""

  get_image_path "$IMAGE_ID"

  IMAGE_HOOK_FUNCTION=""
  get_image_hook "$IMAGE_ID"

  echo "Got Image path '$IMAGE_PATH' and hook '$IMAGE_HOOK_FUNCTION' "

  if [[ IMAGE_ID -eq "99" ]]
  then
    DRIVES_MAX="4" 
    prep_before_duplication
  fi

  echo -ne "How many disks do you want to flash 1-$DRIVES_MAX: " 
  read HOW_MANY

  if [[ HOW_MANY -gt "$DRIVES_MAX" ]] || [[ HOW_MANY -lt "$DRIVES_MIN" ]] 
  then
    echo "Expected $DRIVES_MIN-$DRIVES_MAX. Got $HOW_MANY. Exiting";
    return
  fi


  flash_x_drives $HOW_MANY $IMAGE_PATH $IMAGE_HOOK_FUNCTION
}

function get_active_disk_array () {
  DISK_ARRAY=($(ls /dev/disk/by-id/* | grep -v '\-part' | grep 'SATA' ))
}

function print_active_disks () {
  DISK_ARRAY=()
  get_active_disk_array

  i=0

  for disk_path in "${DISK_ARRAY[@]}" ; do
    disk_size=""
    get_disk_size $disk_path
    echo -e "$i\t$disk_size\t$disk_path\t"
    let "i=$i+1"
  done
}

function select_disk() {
  echo ""
  echo -e $1
  DISK_ARRAY=()
  get_active_disk_array
  print_active_disks

  echo -ne "Select disk 0-${#DISK_ARRAY[@]}: "
  read DISK_INDEX

  disk_path=${DISK_ARRAY[$DISK_INDEX]}


  if [[ -z "$disk_path" ]]
  then
        echo -ne "Bad choice. Exiting.\n"
        exit 1;
  fi

  disk_size=""
  get_disk_size $disk_path

  echo -ne "\nSelected disk:\n"
    echo -e "$DISK_INDEX\t$disk_size\t$disk_path\t"

  read -p "Continue? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo "Continuing..."
  else
    echo "Aborting"
    exit 1;
  fi
}

function get_primary_disk() {
  echo ""
  echo -e $1
  DISK_ARRAY=()
  get_active_disk_array
  print_active_disks

  disk_path=${DISK_ARRAY[0]}

  if [[ -z "$disk_path" ]]
  then
        echo -ne "Bad choice. Exiting.\n"
        exit 1;
  fi

  disk_size=""
  get_disk_size $disk_path

  echo -ne "\nSelected disk:\n"
    echo -e "$DISK_INDEX\t$disk_size\t$disk_path\t"
}



function erase_disk() {
  disk_path=""
  select_disk "Select disk to ${RED}ERASE!${NC}"
  echo "Erasing disk $disk_path..."
  dd if=/dev/zero of=$disk_path bs=4M count=1 status=progress; sync;
}

function system_info() {

echo -e "\n########## DISKS ##########"
print_active_disks

echo -e "\n########## CPU ###########"
cat /proc/cpuinfo | grep "model name"

echo -e "\n########## BOARD NAME  ###########"
cat /sys/class/dmi/id/board_name

echo -e "\n########## BIOS VERSION ###########"
cat /sys/class/dmi/id/bios_version

echo -e "\n########## PCI ###########"
lspci | grep -v "bridge" | grep -v "VGA" | grep -v "Audio" | grep -v "[AMD]"


echo -e "\n########## USB ###########"
lsusb | grep -v "Linux Foundation" | grep -v "Advanced Micro Devices, Inc."

#echo -e "\n########## SENSORS ###########"
#sensors;

beep
}
