#!/bin/sh

snapname="${1}"
src_pool="${2}"
[ -n "${3}" ] && src_keep="${3}" || src_keep=""
[ -n "${4}" ] && send_pool="${4}" || send_pool=""
[ -n "${5}" ] && send_keep="${5}" || send_keep=""
[ -n "${6}" ] && bookmark="${6}" || bookmark="${snapname}"

[ -n "`which zfs`" ] && zfs=`which zfs` || exit 1
[ -n "`which grep`" ] && grep=`which grep` || exit 1
[ -n "`which tail`" ] && tail=`which tail` || exit 1
[ -n "`which head`" ] && head=`which head` || exit 1
[ -n "`which expr`" ] && expr=`which expr` || exit 1
[ -n "`which cut`" ] && cut=`which cut` || exit 1
[ -n "`which date`" ] && date=`which date` || exit 1

datetime="`date +"%Y-%m-%d-%Hh%M"`"

for dataset in `${zfs} list -H -o name -r ${src_pool}`; do
  snap="${snapname}-${datetime}"

  # snapshot
  ${zfs} snapshot ${dataset}@${snap}

  # src clean
  if [ -n "${src_keep}" ]; then
    cnt=0
    for snapshot in `${zfs} list -H -o name -t snap -r "${dataset}" | ${grep} "${dataset}@${snapname}" | ${tail} -r`; do

      if [ ${cnt} -lt ${src_keep} ]; then
        cnt=`${expr} ${cnt} + 1`
        continue;
      fi;

      ${zfs} destroy "${snapshot}"

    done;
  fi;


  ## send routine
  if [ -n "${send_pool}" ]; then
    tmp_src_pool="`echo ${src_pool} | sed -E 's,/,\\\\/,g'`"
    p="`echo ${dataset} | sed -E 's/^'${tmp_src_pool}'//' | sed -E 's/^\///'`"
    [ -n "${p}" ] && send_dataset="${send_pool}/${p}" || send_dataset="${send_pool}"
  fi

  # send backup
  if [ -n "${send_dataset}" ]; then
    if [ -z "`${zfs} list -H -o name -t bookmark | ${grep} "${dataset}#${bookmark}"`" ]; then
      ${zfs} send "${dataset}@${snap}" | ${zfs} recv -uF "${send_dataset}" \
        && ${zfs} bookmark "${dataset}@${snap}" "${dataset}#${bookmark}"
    else
      ${zfs} send -i "${dataset}#${bookmark}" "${dataset}@${snap}" | ${zfs} recv -uF "${send_dataset}" \
        && ${zfs} destroy "${dataset}#${bookmark}" \
        && ${zfs} bookmark "${dataset}@${snap}" "${dataset}#${bookmark}"
    fi
  fi

  # send clean
  if [ -n "${send_keep}" ] && [ -n "${send_dataset}" ]; then
    cnt=0
    for snapshot in `${zfs} list -H -o name -t snap -r "${send_dataset}" | ${grep} "${send_dataset}@${snapname}" | ${tail} -r`; do

      if [ ${cnt} -lt ${send_keep} ]; then
        cnt=`${expr} ${cnt} + 1`
        continue;
      fi;

      ${zfs} destroy "${snapshot}"

    done;
  fi;

done;
