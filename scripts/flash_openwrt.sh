#!/bin/bash -e

#source ./disk_utils/flashing_utils.sh

function get_disk_size () {
  DISK_PATH=$1

  disk_size=$(parted $DISK_PATH print --machine --script 2>/dev/null | grep "/dev/" | awk -F: '{print $2}')
  # echo "$DISK_PATH $disk_size"
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

IMAGE=/root/images/openwrt-21.02.0.configured.img.gz
disk_path="/dev/null"

get_primary_disk


#dd if=$IMAGE of=$disk_path bs=256K; sync;
gunzip -c $IMAGE | dd of=$disk_path bs=256K; sync;

while [ ! -e "${disk_path}-part2" ];
do
  echo "Waiting for ${disk_path}-part2 to appear"
  sleep 1;
done

parted $disk_path resizepart 2 $disk_size  || :
e2fsck -fy "${disk_path}-part2"  || :
resize2fs "${disk_path}-part2" || :

beep
