#!/bin/bash
#
# Copyright (c) 2023, Sergio Arroutbi Braojos <sarroutbi (at) redhat.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
DIR=/var/db/tang
TOTAL_LINES=
TANGD_PORT=81
LOGFILE="/tmp/$(basename "$0" | sed s/\.sh//g)"
CURRENT_HTTP_REQ="GET"

function usage() {
  echo "$1 [-l logfile]"
  exit "$2"
}

while getopts "l:h" arg
do
  case "${arg}" in
    l) LOGFILE=${OPTARG}
       echo "CONTEXT=${CONTEXT}"
       ;;
    h) usage "$0" 0
       ;;
    *) usage "$0" 1
       ;;
  esac
done

{
    echo "***************************************" 
    echo "PID:$$" >> "${LOGFILE}"
    echo "TANG PID:$(pgrep tangd)" >> "${LOGFILE}"
    echo "***************************************"
}  >> "${LOGFILE}"

while read -r line;
do
    echo "init line:${line}" >> "${LOGFILE}"
    echo "CONTENT_LENGTH=${CONTENT_LENGTH}" >> "${LOGFILE}"
    line_length=$((${#line}+1)) # It considers new line
    echo "line_length=${line_length}" >> "${LOGFILE}"    
    if echo "${line}" | grep "POST /rec" > /dev/null;
    then
        CURRENT_HTTP_REQ="POST"
    fi

    ################ THIS PART SHOULD BE DONE PROGRAMATICALLY WITH A CONFIGURATION FILE ######################
    ################ CONFIGURATION SHOULD HAVE SOMETHING LIKE:
    ################ "w1":"/var/db/tang1"
    ################ "w2":"/var/db/tang2"
    if echo "${line}" | grep -E "GET /adv/w1[\/]{0,1}" > /dev/null; then
        line=${line/"/w1"/}
        DIR=/var/db/tang1
    elif echo "${line}" | grep -E "GET /adv/w2[\/]{0,1}" > /dev/null; then
        line=${line/"/w2"/}
        DIR=/var/db/tang2
    elif echo "${line}" | grep -E "POST /rec/w1/[a-z,A-Z,0-9,]{1,}" > /dev/null; then
        line=${line/"/w1"/}
        DIR=/var/db/tang1
    elif echo "${line}" | grep -E "POST /rec/w2/[a-z,A-Z,0-9,]{1,}" > /dev/null; then
        line=${line/"/w2"/}
        DIR=/var/db/tang2
    fi
    ############### /THIS PART SHOULD BE DONE PROGRAMATICALLY WITH A CONFIGURATION FILE ######################
    
    if echo "${line}" | grep -E "Content-Length:" > /dev/null; then
        CONTENT_LENGTH=$(echo "${line}" | awk -F ":" '{print $2}' | sed 's/ //g' | tr -d '\r')
        echo "PARSED CONTENT_LENGTH=${CONTENT_LENGTH}" >> "${LOGFILE}"
    fi
    TOTAL_LINES=$(printf "%s\n%s" "${TOTAL_LINES}" "${line}")
    echo "[${#line}] line:$(echo "${line}" | tr -d '\n' | tr -d '\r')" >> "${LOGFILE}"
    if [ -n "${CONTENT_LENGTH}" ]; then
        echo "[HEXDUMP] line_length:$(echo "${line_length}" | hexdump)" >> "${LOGFILE}"
        echo "[HEXDUMP] CONTENT_LENGTH:$(echo "${CONTENT_LENGTH}" | hexdump)" >> "${LOGFILE}"
    fi
    if [ "${CURRENT_HTTP_REQ}" = "GET" ] && [ "${line}" = $'\r' ]; then
        killall -9 tangd ; /usr/libexec/tangd -l -p "${TANGD_PORT}" "${DIR}" &
        {
            echo "-----------GET------------"
            echo "TOTAL_LINES:${TOTAL_LINES}"
            echo "TANG PID:$(pgrep tangd)"
            echo "----------/GET------------"
        } >> "${LOGFILE}"
        echo "${TOTAL_LINES}" | socat - "tcp:localhost:${TANGD_PORT}"
        TOTAL_LINES=""
    fi
    if [ "${CURRENT_HTTP_REQ}" = "POST" ] && [ "${line_length}" = "${CONTENT_LENGTH}" ]; then
        killall -9 tangd ; /usr/libexec/tangd -l -p "${TANGD_PORT}" "${DIR}" &
        {
            echo "-----------POST--------------"
            echo "TOTAL_LINES:${TOTAL_LINES}"
            echo "TANG PID:$(pgrep tangd)"
            echo "----------/POST-------------"
        } >> "${LOGFILE}"
        echo "${TOTAL_LINES}" | socat - "tcp:localhost:${TANGD_PORT}"
        TOTAL_LINES=""
    fi
done
