#!/bin/bash
#
#   Copyright 2018 M Hightower
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# nar.sh
#
# A simple bash script to download the SPIFFS filesystem files from an
# ESP8266 running an Arduino compatible sketch with Web Server. A UStar
# formated archive (tar) file is created. The file names from the SPIFFS
# filesystem will have the prefix "data.nar" added to the beginning of the
# SPIFFS file names. If the file name does not have a leading "/", one will
# be inserted. The last modification time of an archived file, will be the
# time it was downloaded.


#
# Files that are stored:
#
# A jason list of files to download, downloaded from the server.
#      ~/Downloads/${argTarget}/list
#
# A copy of the "http://..."" addess of the server
#      ~/Downloads/${argTarget}/httpTarget
#
# A UStar formated tar file of the files downloaded from the server.
#      ~/Downloads/${argTarget}/spiffs.[tar, tar.gz, or tgz]
#

unset targetBasePath
#
# If targetBasePath is not defined, the archive directory is writen at
# present working directory.
#
targetBasePath="~/Downloads"
#
# The SPIFFS file names that go into the tar file are modified,
# by inserting this prefix to the beginning of the filename.
#
tarEntryPrefix="data"

#
# Insure proper path endings, etc. for later.
targetBasePath="${targetBasePath%/}"
tarEntryPrefix="${tarEntryPrefix%/}"

printUsage(){
  cat <<EOF

nar - Network ARchiver for Arduino ESP8266 web servers.

A simple bash script to download the SPIFFS filesystem files from an ESP8266
running an Arduino compatible sketch with Web Server. A UStar formated archive
(tar) file is created. The file names from the SPIFFS filesystem will have the
prefix "${tarEntryPrefix}" added to the beginning of the SPIFFS file names. If
the file name does not have a leading "/", one will be inserted. The last
modification time of an archived file, will be the time it was downloaded.


Usage:

  $namesh

      --listonly --source=[USER[:PASSWORD]@]SERVER --target=FOLDER
      --listonly [USER[:PASSWORD]@]SERVER --target=FOLDER
        ... [--update]

      --source=[USER[:PASSWORD]@]SERVER] --target=FOLDER
        [USER[:PASSWORD]@]SERVER --target=FOLDER
      --target=FOLDER [--user=USER[:PASSWORD]]
        ... [--anon]
        ... [--setmode=MODE]
        ... [--update]
        ... [--tgz | --gzip]

  Supported options:

    --source=[USER[:PASSWORD]@]SERVER or just
      [USER[:PASSWORD]@]SERVER
      Specify the [USER[:PASSWORD]@] part, when authentication is required.
      SERVER name would be the Network name (DNS, mDNS, ...) of the device
      with a SPIFFS to download.

    --listonly (optional)
      Only the list of the files available for download is create.
      No files are download. On succes, you will find the list at
      "${targetBasePath}/<target folder name>/list". The options requires
      "--from".

    --target=FOLDER
      The name of the folder that will be created in the default directory,
      "${targetBasePath}". This folder is used to store the
      "list" of files and the archive, spiffs.tar, of the files
      downloaded from the server.
    --target=./FOLDER
      If FOLDER has a leading "./" the folder is created in the current
      directory. If the default diretory is not defined, as would be indicated
      by empty quotes above, "", then a FOLDER w/o "./" will also be created
      in the current directory.
      If "--target=..." is the only argument it is assumed that the
      "list" file is already in the FOLDER specified. (Possibly edited
      down.) The files listed in "list" will be downloaded. Note you may
      need to add the --user parameter for server authentication.

    --user=USER[:PASSWORD] (as needed)
      Provides authentication information when needed.

    --update (optional)
      Allows reuse of an old archive directory.
      Removes files that $namesh uses, before running.

    --setmode=<access mode bits in octal> (optional)
      Defaults to 0664.

    --anon  (optional)
      By default, owner and group information recorded in the tar
      backup file is that of the account running the script.
      This option changes the owner to "spiffs" and the group to "Arduino".
      And, UID and GID are set to 0.

    --tgz or  (optional)
    --gzip
      Either will run gzip on the newly completed archive file; however,
      --tgz the will replace the .tar.gz extension with .tgz

    --help
      This usage message.

EOF
  return 1
}


namesh="${0##*/}"
baseName="${namesh%.*}"
unset errorExitFlag
msgWidth=72

# $1 subject, $2 text to log
# Usage: logit "${FUNCNAME[0]}" "This did not work"
logit() {
#  timestamp=`date  +'%Y-%m-%d %H:%M:%S'`
  timestamp="ARG:"
  local logStr
  logStr="${2//\\n/$'\n'}"
  logStr="${logStr%$'\n'}"
  logStr="${logStr//$'\n' /$'\n'}"
  echo "${logStr}" | sed "s\\^\\$timestamp ${1}${1:+: }\\">>$logfile
}

beginLogFile() {
  logfile=$( printf "%q" "/tmp/${baseName}_$(date '+%s').log" )
  if ! [[ -n "$logfile" && -f $logfile ]]; then
    touch $logfile
    chmod 664 $logfile
    logit "" "-------- Started ${logfile} ---------"
  fi
}

logError() {
  if [[ -z ${logfile} ]]; then beginLogFile; fi
  local i trace func calledFrom
  i=0
  calledFrom="${LINENO}"
  for func in "${FUNCNAME[@]}"; do
    trace="${func}(${calledFrom})->${trace}"
    calledFrom="${BASH_LINENO[$i]}"
    i=$(( $i + 1 ))
  done
  trace="${trace%->logError*}"
  trace="${0##*/}${trace#main}"
  logit "*** ${trace}" "${*}"
  if [[ -z "${errorExitFlag}" ]]; then
    errorExitFlag=1 # "${trace}: ${1}"
  fi
}

# # http://mywiki.wooledge.org/BashFAQ/002
# # https://stackoverflow.com/questions/3811345/how-to-pass-all-arguments-passed-to-my-bash-script-to-a-function-of-mine/3816747
# runcurl() { curl -s "$@"; }
# runcmd() {
#   local _rc _result
#   _result=$(
#     { stdout=$( "$@" ); returncode=$?; } 2>&1
#     printf "this is the separator"
#     printf "%s\n" "$stdout"
#     exit "$returncode"
#   )
#   _rc=$?
#
#   cmd_out=${_result#*this is the separator}
#   cmd_err=${_result%this is the separator*}
#   if [[ $_rc -ne 0 ]]; then
#     logError "runcmd failed with exit code ${_rc}: $@\n${cmd_err}"
#   fi
#   return $_rc
# }

buildHttpText() {
  local _text
  _text=$( echo -n "$1" | jq -R '@uri' )
  # Strip quotes
  eval _text=${_text}
  eval ${2:-text}="\${_text}"
}

sendHttpRequest() {
  local result rc errorMsg _targetFileSize
  if [[ -n ${2} ]]; then
    if [[ -f ${2} ]]; then
      _targetFileSize=$( stat --printf="%s" ${2} )
    else
      _targetFileSize=0
    fi
    errorMsg=$(
        { curl -sS $1 "${httprequest}">>${2}; rc2=$?; } 2>&1
          exit $rc2
      )
    rc=$?
    if [[ $rc -ne 0 ]]; then
      if [[ -z ${argDebug} ]]; then
        if [[ $rc -eq 6 ]] || [[ $rc -eq 7 ]]; then
          echo -e "\n*** Error: ${errorMsg}"
          return $rc
        fi
      fi
      logError "Sent http Request: $httprequest"
      logError "cmd=curl -sS $1 \"${httprequest}\""
      logError "Exit code: $rc"
      logError "Error Msg: ${errorMsg}"
      return $rc
    fi
    if [[ $( stat --printf="%s" ${2} ) -eq ${_targetFileSize} ]]; then
      if [[ -z ${argDebug} ]]; then
        echo -e "\n*** Error: curl returned a null response on success." \
                "\n*** This is a common response for authentication failure." \
                "\n*** Check user name and password."
        return 100
      fi
      logError "Sent http Request: $httprequest"
      logError "cmd=curl -sS $1 \"${httprequest}\""
      logError "curl returned a null response on success."
      logError "Check user name and password."
      return 100
    fi
  else
    logError "File name for result missing."
    return 1
  fi
  return 0
}

validPosixFilter="^[a-zA-Z0-9._\-]+$"
validPosixName() {
  if [[ "${1}" =~ ${validPosixFilter} ]]; then
    return 0
  fi
  return 1
}

# TODO Expand list of valid characters
validLinuxFilter="[^\0]+$"
validLinuxPath() {
  if [[ "${1}" =~ ${validLinuxFilter} ]]; then
    return 0
  fi
  return 1
}

validNetworkName() {
  local _portNumber _netName
  if [[ "${1}" =~ :[0-9] ]]; then
    _portNumber=${1/#*:}
    if ! [[ "${_portNumber}" =~ ^[0-9]+$ ]]; then return 1; fi
    if [[ $_portNumber -ge 65536 ]]; then return 1; fi
  fi
  _netName=${1/%:*}
  return $( validPosixName "${_netName}" )
}

validOctalNumber() {
  if [[ "${1}" =~ ^[0-7]+$ ]]; then
    return 0
  fi
  return 1
}

getList() {
  httprequest="${httpTarget}/edit?list"
  sendHttpRequest "--user ${1}" "${2}"
  rc=$?
  return $rc
}

downloadFile() {
  buildHttpText "${remoteFileName}" text
  httprequest="${httpTarget}/edit?download=${text}"
  sendHttpRequest "--user ${1}" "$2"
  rc=$?
  return $rc
}

printFolded() {
  local prefix="${1}"
  shift
  local logStr
  logStr="${*//\\n/$'\n'}"
  #+ logStr="${logStr%$'\n'}"
  logStr="${logStr//$'\n' /$'\n'}"
  if [[ -z ${prefix} ]]; then
    echo "${logStr}" | fold -s -w $msgWidth
  else
    echo "${logStr}" | fold -s -w $(( $msgWidth - ${#prefix} - 1 )) | sed "s/^/${prefix} /"
  fi
}

# function makeArray() {
#     local IFS=$'\n'
#     eval ${1}=\(\${2}\)
# }

make_spiffsNames() {
  local IFS=$'\n'
  spiffsNames=( `cat ${listFileName} | jq -r '.[] | select(.type=="file") | .name,.size'` )
}

# tarPrintOctal value fieldWidth
tarPrintOctal() {
  local fieldWidth=${2:-0}
  if [[ ${fieldWidth} -ne 0 ]]; then
    fieldWidth=$(( ${fieldWidth} - 1 ));
  fi
  printf "%.*o\0" ${fieldWidth} ${1} >>${tarFileName}
}

# Write a tar Header at the end of the specified file.
# If file does not exist, use touch before calling
#
# Variables
# Uses from script:
#   tarHdrOffset, fileSize, fileName, tarFileName, fileMode
#   userID, groupID, userName, groupName
# Uses from System: USER, GROUPS,
#
# Updates:
#   tarHdrOffset
#
# Based on information from: https://en.wikipedia.org/wiki/Tar_(computing)
tarWriteHeader() {
  local checksum
  if ! [[ -f ${tarFileName} ]]; then  errorExit 254; fi
  # Header should always start on a 512 byte boundary
  truncate -c -s %512 ${tarFileName}
  tarHdrOffset=$( stat --printf="%s" ${tarFileName} )
  printf "%s" "${fileName}" >>${tarFileName}
  truncate -c -s $(( ${tarHdrOffset} + 100 )) ${tarFileName}
  tarPrintOctal ${fileMode:-0664} 8
  tarPrintOctal ${userID:-${EUID}} 8
  tarPrintOctal ${groupID:-${GROUPS}} 8
  tarPrintOctal ${fileSize} 12   # file size
  # Last modification time, use now.
  tarPrintOctal $(date +'%s') 12
  # Checksum field needs blanks for calculating checksum.
  printf "%8.s" "">>${tarFileName}
  # Link indicator (file type)
  printf "0" >>${tarFileName}
  # UStar indicator and Version
  # Every reference I have seen says the version should be "00"
  # Thus printf "ustar\0%s" "00" gives the , a bit tricky
  # However, gnu tar is using "utar  \0" (spaces).
  # I am tried "00" and gnu tar did not complain.
  truncate -c -s $(( ${tarHdrOffset} + 257 )) ${tarFileName}
#  printf "ustar\0%s" "00" >>${tarFileName}
  printf "ustar  \0" >>${tarFileName}
  # User Name field 32 bytes
  truncate -c -s $(( ${tarHdrOffset} + 265 )) ${tarFileName}
  printf "%s" ${userName:-${USER}} >>${tarFileName}
  # Group name field 32 bytes
  truncate -c -s $(( ${tarHdrOffset} + 297 )) ${tarFileName}
  printf "%s" ${groupName:-`id -gn ${USER}`} >>${tarFileName}
  truncate -c -s %512 ${tarFileName}
  # Now compute checksum and patch header
  checksum=$( dd status=none iflag=skip_bytes,count_bytes \
                skip=${tarHdrOffset} count=512 if=${tarFileName} | sum -s )
  printf "%6.6o\0 " ${checksum/ */} | \
  dd conv=nocreat,notrunc status=none \
    iflag=count_bytes count=8 \
    oflag=seek_bytes seek=$(( ${tarHdrOffset} + 148 )) of=${tarFileName}
}

errorExit() {
  if [[ -f ${logfile} ]]; then
    cat ${logfile}
    rm ${logfile}
    echo ""
  fi
  exit ${1:-255}
}

unset httpTarget

unset argFrom argTarget argHelp argListOnly argError argUser argGzip \
      argMode argAnon argUpdate userName groupName userID groupID argDebug


# --user@([ =])*) argUser="${1/[ =]/ }"; ;;
shopt -s extglob
while [[ -n ${1} ]]; do
  case "${1,,}" in
    --listonly)      argListOnly=1; ;;
    --target?(=*))   if [[ "$1" = "--target" ]]; then shift; fi
                     argTarget=${1#--target=}; ;;
    --user?(=*))     if [[ "$1" = "--user" ]]; then shift; fi
                     argUser="${1#--user=}"; ;;
    --source?(=*@*)) if [[ "$1" = "--source" ]]; then shift; fi
                     ;&
      *@*)           argUser="${1#--source=}"
                     argUser="${argUser/@*/}"
                     argFrom="${1/*@/}"
                     if [[ "$argUser" = "$argFrom" ]]; then
                       unset argUser
                     fi; ;;
    --setmode?(=*))  if [[ "$1" = "--setmode" ]]; then shift; fi
                     argMode=${1#--setmode=}; ;;
    --anon*)         userName="spiffs"; groupName="Arduino"
                     userID=0; groupID=0; ;;
    --tgz)           argGzip="tgz"; ;;
    --gzip)          argGzip="gz"; ;;
    --update)        argUpdate=1; ;;
    --debug)         argDebug=1; ;;
    --help)          argHelp=1; ;;
    *) argHelp=1; argError="${argError}\nUnknown option: \"${1}\""; ;;
  esac
  if [[ -n ${1} ]]; then shift; fi
done

echo ""

if [[ -n ${argDebug} ]]; then
  logError \
    "argUser=$argUser\n"\
    "argFrom=$argFrom\n"\
    "argMode=$argMode\n"\
    "argTarget=$argTarget\n"\
    "argError=$argError\n"
fi

#
# Validate command line parameters
#
if [[ -n ${argMode} ]]; then
  if validOctalNumber "${argMode}"; then
    fileMode=0${argMode}
  else
    argHelp=1; argError="${argError}\n--setMode parameter's value is invalid. The value should be an octal number."
  fi
fi

if [[ -z ${argTarget} ]] && [[ -z ${argHelp} ]]; then
  argHelp=1; argError="${argError}\n--target parameter required."
fi
if [[ -n ${argListOnly} ]] && [[ -z ${argFrom} ]]; then
  argHelp=1; argError="${argError}\n--from parameter required, when using --listonly."
fi

if [[ -n ${argHelp} ]]; then
  if [[ -n ${argError} ]]; then
    echo -e "${argError}\n"
  fi
  printUsage
  errorExit 1
fi



if ! validLinuxPath "${argTarget}"; then
  printFolded "***" "\nBad directory name, \"${argTarget}\"\n"
  errorExit 1
fi

if [[ "${argTarget:0:2}" = "~/" ]]; then
  target=~/"${argTarget#\~/}"
elif [[ "${argTarget:0:2}" = "./" ]]; then
  target="${argTarget#./}"
elif [[ "${argTarget:0:1}" = "/" ]]; then
  printFolded "***" "\n"\
    "Bad directory name, \"${argTarget}\"."\
    "Cannot create directory at the root of the filesystem, \"/\"."\
    "Please run command from the directory level you wish to create"\
    "the archive directory."\
    "\n"
  errorExit 1
else
  unset expandedBasePath
  if [[ -n "${targetBasePath}" ]]; then
    if [[ "${targetBasePath:0:2}" = "~/" ]]; then
      expandedBasePath=~/"${targetBasePath#\~/}"
    else
      printFolded "***" "\n"\
        "Default targetBasePath has been changed. The value needs to be set"\
        "to something of the form: \"~USER\", \"~USER/SUBDIR1\", \"~/Downloads\", etc."\
        "This is more a safe guard than anything else.\n"
      errorExit 1
    fi

    if ! [[ -d "${expandedBasePath}" ]]; then
      echo -e "\n\n"
      echo "The expanded base directory path \"${expandedBasePath}\","
      echo "does not exist."
      echo -n "Would you like to create it now (yes/no)? "
      unset yesno
      gotit=-1
      for (( i=16; (i>0)&&(${gotit}<0); i-=1 )); do
        read yesno
        echo ""
        case "${yesno,,}" in
          yes) if mkdir -p "${expandedBasePath}"; then
                 gotit=1;
               else
                 gotit=0
               fi
               ;;
          no)  gotit=0;
               ;;
          *)   echo -n "Please type 'yes' or 'no': "
               ;;
        esac
      done
      echo ""
      if [[ $gotit -lt 1 ]] || ! [[ -d "${expandedBasePath}" ]]; then
        errorExit 1
      fi
    fi

    target="${expandedBasePath}/${argTarget#/}"

  else # zero ${targetBasePath}
    # Check if PWD is root
    if [[ "${PWD}" = "/" ]]; then
      printFolded "***" "\n"\
        "Current directory is at \"${PWD}\"."\
        "Cannot create directory at the root of the filesystem, \"/\"."\
        "Please run command from the directory level you wish to create"\
        "the archive directory."\
        "\n"
      errorExit 1
    else
      target="${argTarget}"
    fi
  fi
fi
target_q=$( printf "%q" "${target}" )
if [[ -z "${target}" ]]; then
  logError \
    "targetBasePath=${targetBasePath}\n"\
    "argTarget=${argTarget}"
    "expandedBasePath=${expandedBasePath}\n"\
    "target=${target}\n"
  printFolded "\n***" "Internal error: \"target\" not set.\n"
  errorExit 1
fi
logError \
  "targetBasePath=${targetBasePath}\n"\
  "expandedBasePath=${expandedBasePath}\n"\
  "target=${target}\n"\
  "target_q=${target_q}\n"

# errorExit 1

if [[ -n ${argFrom} ]]; then
  if validNetworkName "${argFrom}"; then
    httpTarget="http://${argFrom}"
  else
    echo -e "\n*** Bad Network name, \"${argFrom}\"\n"
    errorExit 1
  fi
fi

#
# Deal with target directory
#
if [[ -f ${target_q} ]]; then {
  echo -e "\n*** Failed, target directory, \"${target_q}\"," \
          "\n*** already exists as a file.\n"
  ls -l ${target_q}
  errorExit 1
} elif [[ -d ${target_q} ]]  && [[ -z ${argUpdate} ]]; then {
  if [[ -f ${target_q}/spiffs.tar ]] || [[ -f ${target_q}/spiffs.tgz ]]; then
    echo -e "\n*** Failed, target directory, \"${target_q}\"," \
            "\n*** already contains a SPIFFS backup.\n"
    ls -l ${target_q}
    errorExit 1
  elif [[ -f ${target_q}/list ]]; then
    if [[ -n "${argFrom}" ]]; then
      echo -e "\nExisting download list, \"${target_q}/list\"," \
              "\nwill be overwriten." \
              "\n"
      # TODO ask for confirmation
    else
      echo "Using download list found at \"${target_q}/list\"."
    fi
  fi
} else {
  if [[ -d ${target_q} ]]  && [[ -n ${argUpdate} ]]; then
    #
    # Cleanup directory, only remove our things.
    #
    if [[ -n ${argFrom} ]]; then
      echo -e "Removing old backup information from:" \
            "\n  ${target_q}"
      if [[ -f ${target_q}/list ]]; then
        rm ${target_q}/list
      fi
      if [[ -f ${target_q}/httpTarget ]]; then
        rm ${target_q}/httpTarget
      fi
    else
      echo -e "Keeping previous \"--from\" information and removing other old backup information from:" \
            "\n  ${target_q}"
    fi

    if [[ -f ${target_q}/spiffs.tar ]]; then
      rm ${target_q}/spiffs.tar
    fi
    if [[ -f ${target_q}/spiffs.tgz ]]; then
      rm ${target_q}/spiffs.tgz
    fi
    if [[ -f ${target_q}/spiffs.tar.gz ]]; then
      rm ${target_q}/spiffs.tar.gz
    fi
    if [[ -f ${target_q}/spiffs.tgz ]]; then
      rm ${target_q}/spiffs.tgz
    fi
  else
    mkdir -p ${target_q}
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
      echo -e "\n*** Failed, could not create target directory, \"${target_q}\".\n"
      ls -l ${target_q}
      errorExit ${rc}
    fi
    if ! [[ -d ${target_q} ]]; then
      echo -e "\n*** Something strange happended. mkdir failed to create directory.\n"
      ls -l ${target_q}
      errorExit 254
    fi
  fi
} fi

#
# Construct vars for with escaped filenames
#
listFileName=$( printf "%q" "${target}/list" )
httpFileName=$( printf "%q" "${target}/httpTarget" )
tarFileName=$( printf "%q" "${target}/spiffs.tar" )

#
# download list
#
if [[ -n ${httpTarget} ]]; then
  echo -e "\nDownloading a \"list\" of files to download."
  if getList "${argUser}" "${listFileName}"; then
    echo -n "${httpTarget}" >${httpFileName}
  else
    echo -e   "*** Failed to get file list from \"${httpTarget}\"." \
            "\n"
    errorExit 1
  fi
else
  if [[ -f ${httpFileName} ]] && [[ -f ${listFileName} ]]; then
    httpTarget=$( cat "${target_q}/httpTarget" )
    argFrom=${httpTarget##*/}
  else
    unset httpTarget response
  fi
fi

if [[ -z ${httpTarget} ]] || ! [[ -f ${listFileName} ]]; then
  echo -e "\n*** Cannot find previously saved information." \
          "\n*** Run command again with the \"--from=...\" option." \
          "\n"
  ls -l ${target_q}
  errorExit 1
fi

if [[ -n ${argListOnly} ]]; then
  echo -e "\nResults saved in:" \
          "\n  \"${target_q}\"" \
          "\n"
  ls -l ${target_q}
  echo ""
  exit 0
fi

#
# Download files and build tar file
#
echo -e "\nCreating nar backup of ${argFrom}'s SPIFFS file system." \
        "\nResults will be writen to folder: \"${target_q}\"."
if [[ -f ${tarFileName} ]]; then
  echo -e "\n" \
          "\n*** Internal check failed: \"{tarFileName}\" alread exist." \
          "\n"
  errorExit 1
else
  touch ${tarFileName}
fi

# spiffsNames=( `echo -n "${response}" | jq -r '.[] | select(.type=="file") | .name'` )
make_spiffsNames
numOfFilesToBackup=$(( ${#spiffsNames[@]} / 2 ))
if [[ $(( ${#spiffsNames[@]} % 2 )) -ne 0 ]]; then
  echo -e "\n*** The list of files to backup is corrupted." \
          "\n"
  errorExit 1
fi
numFilesBackedUp=0
echo ""
for (( i=0; i<${#spiffsNames[@]}; i+=2 )); do
  fileName="${tarEntryPrefix}/${spiffsNames[i]#/}"
  remoteFileName="${spiffsNames[i]}"
  fileSize=${spiffsNames[i+1]}
  echo -n -e "\rDownloading: $(( ${numFilesBackedUp} + 1 )) of ${numOfFilesToBackup} size ${fileSize}, name \"${spiffsNames[i]}\"\e[K"
  tarWriteHeader
  if downloadFile "${argUser}" "${tarFileName}"; then
    tarFileSize=$( stat --printf="%s" ${tarFileName} )
    estimateSize=$(( ${fileSize} + 512 + $tarHdrOffset ))
    if [[ ${tarFileSize} -ne ${estimateSize} ]]; then
      echo -e "\n" \
              "\n*** Error in adding ${fileName}, \(${fileSize} bytes\) to archive file." \
              "\n*** Actual files size does not match estimate." \
              "\n*** Estamated file size: ${estimateSize} vs. actual tar file size: ${tarFileSize}" \
              "\n"
      errorExit 100
    else
      numFilesBackedUp=$(( ${numFilesBackedUp} + 1 ))
    fi
  else
    truncate -c -s +1024 ${tarFileName} # two records of zeros
    truncate -c -s %2048 ${tarFileName}
    echo -e   "*** Error downloading file from ${httpTarget}" \
            "\n*** only ${numFilesBackedUp} of ${#spiffsNames[@]} were backed up." \
            "\n"
    errorExit 1
  fi
done
echo -e "\rSuccess downloading: ${numFilesBackedUp} of ${numOfFilesToBackup} files from ${argFrom}.\e[K"

# For the end of the archive there should be at least two record of 512 bytes
# of zero. The file should be expanded to an integral block size.
# Punt
truncate -c -s +1024 ${tarFileName} # two records of zeros
truncate -c -s %2048 ${tarFileName}


if [[ -n ${argGzip} ]]; then
  gzip ${tarFileName}
  if [[ ${argGzip} = "tgz" ]]; then
    mv ${tarFileName}.gz ${tarFileName/%.tar/.tgz}
  fi
fi

echo -e "\nResults saved in:" \
        "\n  \"${target_q}\"" \
        "\n"
ls -l ${target_q}
echo ""

exit 0

  # # This worked for uploading a file
  # curl -X POST \
  #      -F 'data=@"hi.txt";filename="/thiswasfun.txt"' \
  #  or  -F 'data=@-;filename="/thiswasfun.txt"' \
  #      --user USER:PASSWORD \
  #      "http://irsender4.local/edit"; echo;
  #
  # #    data=@- reads from stdin
  #
  # # This will delete a file
  # curl -X DELETE \
  #      -F "path=/test.txt" \
  #      --user USER:PASSWORD \
  #      "http://irsender4.local/edit"; echo;
  #
