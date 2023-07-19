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
DEFAULT_LOGFILE="/tmp/$(basename "$0" | sed s/\.sh//g)"
CURRENT_HTTP_REQ=
DEFAULT_CONFFILE="/etc/socat-tang-filter.csv"

function usage() {
    echo "$1 [-c csv_file (default:${DEFAULT_CONFFILE})] [-l logfile:(default:${DEFAULT_LOGFILE})]"
    echo
    exit "$2"
}

function msg_usage() {
    echo
    echo "$3"
    echo
    usage "$1" "$2"
}

function dump_log_header() {
    {
        echo "***************************************"
        echo "PID:$$"
        echo "TANG PID:$(pgrep tangd)"
        echo "CONFFILE:${CONFFILE}"
        echo "LOGFILE:${LOGFILE}"
        echo "***************************************"
    }  >> "${LOGFILE}"
}

while getopts "l:c:h" arg
do
    case "${arg}" in
        l) LOGFILE=${OPTARG}
           ;;
        c) CONFFILE=${OPTARG}
           ;;
        h) usage "$0" 0
           ;;
        *) usage "$0" 1
           ;;
    esac
done

test -z "${LOGFILE}"  && LOGFILE="${DEFAULT_LOGFILE}"
test -z "${CONFFILE}" && CONFFILE="${DEFAULT_CONFFILE}"
test -f "${CONFFILE}" || msg_usage "$0" 1 "csv configuration file:${CONFFILE} does not exist"

dump_log_header

while read -r line;
do
    echo "[${#line}] line:$(echo "${line}" | tr -d '\n' | tr -d '\r')" >> "${LOGFILE}"
    line_length=$((${#line}+1)) # It considers new line
    if echo "${line}" | grep "GET /" > /dev/null;
    then
        CURRENT_HTTP_REQ="GET"
        CURRENT_LINE="GET"
    elif echo "${line}" | grep "POST /" > /dev/null;
    then
        CURRENT_HTTP_REQ="POST"
        CURRENT_LINE="POST"
    else
        CURRENT_LINE=""
    fi

    if [ "${CURRENT_LINE}" = "GET" ]; then
        workspace=$(echo "${line}" | awk -F "GET " '{print $2}' | awk -F "/adv" '{print $1}' | tr -d '/')
    elif [ "${CURRENT_LINE}" = "POST" ]; then
        workspace=$(echo "${line}" | awk -F "POST " '{print $2}' | awk -F "/rec" '{print $1}' | tr -d '/')
    fi

    echo "workspace=${workspace}" >> "${LOGFILE}"

    if [ -n "${workspace}" ]; then
        if workspace_dir=$(grep "${workspace}", "${CONFFILE}"); then
            DIR=$(echo "${workspace_dir}" | awk -F ',' '{print $2}' | tr -d '"')
            line=${line/"/${workspace}"/}
            {
                echo "workspace_dir:${workspace_dir} from configuration file:[$CONFFILE]"
                echo "parsed DIR=${DIR} for workspace:${workspace}"
                echo "forward line=${line}"
            } >> "${LOGFILE}"
        fi
    else
        workspace_dir=$(head -1 "${CONFFILE}")
        DIR=$(echo "${workspace_dir}" | awk -F ',' '{print $2}' | tr -d '"')
        {
            echo "No workspace in URL"
            echo "workspace_dir:${workspace_dir} from 1st line of configuration file:[$CONFFILE]"
            echo "parsed DIR=${DIR} for workspace:${workspace}"
            echo "forward line=${line}"
        } >> "${LOGFILE}"
    fi

    if echo "${line}" | grep -E "Content-Length:" > /dev/null; then
        CONTENT_LENGTH=$(echo "${line}" | awk -F ":" '{print $2}' | sed 's/ //g' | tr -d '\r')
        echo "parsed CONTENT_LENGTH=${CONTENT_LENGTH}" >> "${LOGFILE}"
    fi
    TOTAL_LINES=$(printf "%s\n%s" "${TOTAL_LINES}" "${line}")
    if [ -n "${CONTENT_LENGTH}" ]; then
        echo "[HEXDUMP] line_length:$(echo "${line_length}" | hexdump)" >> "${LOGFILE}"
        echo "[HEXDUMP] CONTENT_LENGTH:$(echo "${CONTENT_LENGTH}" | hexdump)" >> "${LOGFILE}"
    fi
    if [ "${CURRENT_HTTP_REQ}" = "GET" ] && [ "${line}" = $'\r' ]; then
        test -d "${DIR}" || mkdir -p "${DIR}"
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
        test -d "${DIR}" || mkdir -p "${DIR}"
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
