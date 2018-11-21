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
# Additional applications required: curl and jq
#   sudo apt-get install curl jq

unset argError
printUsage(){
  if [[ -n ${argError} ]]; then
    echo -e "${argError}\n"
  fi
  cat <<EOF

nar - Network ARchiver for an Arduino ESP8266 with Web Server Running

A simple bash script that will download files from an ESP8266 and create a tar
formated archive file. The ESP8266 must be running a compatible Arduino sketch
with Web Server. The archive file created is of UStar format. The file names
from the SPIFFS filesystem will have the prefix "${tarEntryPrefix}" added to the
beginning of the SPIFFS file names. If the file name does not have a leading
"/", one will be inserted. The last modification time of an archived file,
will be the time this script was started.


Usage:

  $namesh

    Basic command line format:
      $namesh <archive file name> <Network location> <list of files> <optional>

     <archive file name>  expression
       -f=ARCHIVENAME
      --file=ARCHIVENAME
        ARCHIVENAME, the name of the archive file you are creating. Suggest
        using a ".tar" extension to make it easy to identify.
          examples:
            -f=~/backups/spiffs-18-02-30.tar
            --file=spiffs-18-02-30.tar
            --file=~arduino/backups/spiffs/mydevice-18-02-30.tar

     <Network location>  expression
        [USER:PASSWORD@]SERVER
        Specify the [USER:PASSWORD@] part, when authentication is required.
        SERVER name would be the Network name (IP Address, DNS, mDNS, ...) of
        the device with a SPIFFS to download.
          examples:
            mydevice.local
            admin:password@mydevice.local

     <list of files>  expression - optional
    --filter=REGEX
        examples:
          --filter="/w*"
          --filter="/w/*.gz"
          --filter="/w/[0-9]something.jpg"


     <optional>
        Additional optional parameters are shown in the Supported options list.

  Supported options:

     -f=ARCHIVENAME        or
    --file=ARCHIVENAME
      ARCHIVENAME, the name of the archive file you are creating. Suggest
      using a ".tar" extension to make it easy to identify. Alternatively,
      use a ".tgz" extension and gzip will be run on the archive file, after
      it is created.

      [USER:PASSWORD@]SERVER
      Specify the [USER:PASSWORD@] part, when authentication is required.
      SERVER name would be the Network name (IP address, DNS, mDNS, ...) of
      the device with a SPIFFS to download.

    --list    or  (optional)
    --long
      "--list" will only list the files that would have been placed in
      archive file, dry run.
      "--long" is similar to "--list" with file lengths added.

    --filter=REGEX
      A regular expression filter to limit the files downloaded.
      Use with "--long to confirm your selection.

    --replace (optional)
      Overwrite an old backup.

    --prefix=PREFIX
      The file names from the SPIFFS filesystem will have the string PREFIX
      added to the beginning of the SPIFFS file names.
      Defaults to "${tarEntryPrefix}"

    --setmode=<access mode bits in octal> (optional)
      Defaults to 0664.

    --setdate=<time in seconds since 1/1/1970> (optional)
      The timestamp information to assign to all of the files in the archive.
      Defaults to the time the script was started.

    --anon  (optional)
      By default, owner and group information recorded in the tar
      backup file is that of the account running the script.
      This option changes the owner to "spiffs" and the group to "Arduino".
      And, UID and GID are set to 0.

    --gzip
      Run gzip on the newly completed archive file. This is an alternative
      to using the ".tgz" extention.

    --help
      This usage message.

EOF
  return 1
}

# The SPIFFS file names that go into the tar file are modified,
# by inserting this prefix to the beginning of the filename.
# This is a default --prefix=... can overide it.
#
tarEntryPrefix="data"


namesh="${0##*/}"
baseName="${namesh%.*}"
tmp="/tmp"
logfile=$( printf "%q" "${tmp}/${baseName}_$(date '+%s').log" )
tmpFile1=$( printf "%q" "${tmp}/${baseName}_$(date '+%s')Z1.txt" )
tmpList=$( printf "%q" "${tmp}/${baseName}_$(date '+%s')_List.txt" )
msgWidth=72
trap "[[ -f $tmpList ]] && rm $tmpList; [[ -f $tmpFile1 ]] && rm $tmpFile1" EXIT

# $1 subject, $2 text to log
# Usage: logit "subject" "message"
logit() {
#  timestamp=`date  +'%Y-%m-%d %H:%M:%S'`
  timestamp="ARG:"
  local logStr
  logStr="${2//\\n/$'\n'}"
  logStr="${logStr%$'\n'}"
  logStr="${logStr//$'\n' /$'\n'}"
  echo "${logStr}" | sed "s\\^\\$timestamp ${1}${1:+: }\\">>$logfile
}

logError() {
  local i trace func calledFrom
  i=0
  calledFrom="${LINENO}"
  for func in "${FUNCNAME[@]}"; do
    trace="${func}(${calledFrom})->${trace}"
    i=$(( $i + 1 ))
  done
  trace="${trace%->logError*}"
  trace="${0##*/}${trace#main}"
  logit "*** ${trace}" "${*}"
}

# http://mywiki.wooledge.org/BashFAQ/002
# https://stackoverflow.com/questions/3811345/how-to-pass-all-arguments-passed-to-my-bash-script-to-a-function-of-mine/3816747
runcurl() { curl -s "$@"; }
runcmd() {
  local _rc _result
  _result=$(
    { stdout=$( "$@" ); returncode=$?; } 2>&1
    printf "this is the separator"
    printf "%s\n" "$stdout"
    exit "$returncode"
  )
  _rc=$?

  cmd_out=${_result#*this is the separator}
  cmd_err=${_result%this is the separator*}
  if [[ $_rc -ne 0 ]]; then
    logError "runcmd failed with exit code ${_rc}: $@\n${cmd_err}"
  fi
  return $_rc
}

buildHttpText() {
  local _text
  _text=$( echo -n "$1" | jq -R '@uri' )
  # Strip quotes and set
  eval ${2:-text}=${_text}
}

sendHttpRequest() {
  local result rc errorMsg _targetFileSize
  if [[ -z ${2} ]]; then
    logError "File name for result missing."
    return 1
  else
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
    orc=$rc
    if [[ $rc -eq 0 ]]; then
      if [[ ${#errorMsg} -ne 0 ]] &&
         [[ "${errorMsg/Enter host password/}" != "${errorMsg}" ]]; then
          printFolded "***" "\nFailed: Remote host password required."
          rc=250
      elif [[ $( stat --printf="%s" ${2} ) -eq ${_targetFileSize} ]]; then
        if [[ -z ${argDebug} ]]; then
          rc=251
          printFolded "***" "\n"\
            "Failed: curl returned a null response on success."\
            "This is a common response for authentication failure."\
            "Check user name and password."
          return $rc
        fi
        logError "curl returned a null response on success."
        logError "Check user name and password."
      fi
    fi
    if [[ $rc -ne 0 ]]; then
      if [[ -z ${argDebug} ]]; then
        if [[ $rc -eq 6 ]] || [[ $rc -eq 7 ]] || [[ $rc -ge 250 ]]; then
          echo -e "\n*** Error: ${errorMsg}"
          return $rc
        fi
      fi
      logError "Sent http Request: $httprequest"
      logError "cmd=curl -sS $1 \"${httprequest}\""
      logError "Exit code: $orc"
      logError "Error Msg: ${errorMsg}"
      return $rc
    fi
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

# Yep just about anything can go into a linux filesystem name.
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

validDecNumber() {
  if [[ "${1}" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

getList() {
  httprequest="${httpTarget}/edit?list"
  sendHttpRequest "${1:+--anyauth --user }${1}" "${2}"
  rc=$?
  return $rc
}

downloadFile() {
  buildHttpText "${remoteFileName}" text
  httprequest="${httpTarget}/edit?download=${text}"
  sendHttpRequest "${1:+--anyauth --user }${1}" "$2"
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
  spiffsNames=( `cat ${tmpList} | jq -r '.[] | select(.type=="file") | .name,.size'` )
}

# tarPrintOctal value fieldWidth
tarPrintOctal() {
  local fieldWidth=${2:-0}
  if [[ ${fieldWidth} -ne 0 ]]; then
    fieldWidth=$(( ${fieldWidth} - 1 ));
  fi
  printf "%.*o\0" ${fieldWidth} ${1} >>"${tarFileName}"
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
# and https://www.freebsd.org/cgi/man.cgi?query=tar&apropos=0&sektion=5&manpath=FreeBSD+7.0-RELEASE&arch=default&format=html
tarWriteHeader() {
  local checksum
  if ! [[ -f "${tarFileName}" ]]; then  errorExit 254; fi
  # Header should always start on a 512 byte boundary
  truncate -c -s %512 "${tarFileName}"
  tarHdrOffset=$( stat --printf="%s" "${tarFileName}" )
  printf "%s" "${fileName}" >>"${tarFileName}"
  truncate -c -s $(( ${tarHdrOffset} + 100 )) "${tarFileName}"
  tarPrintOctal ${fileMode:-0664} 8
  tarPrintOctal ${userID:-${EUID}} 8
  tarPrintOctal ${groupID:-${GROUPS}} 8
  tarPrintOctal ${fileSize} 12   # file size
  # Last modification time, defaults to now.
  tarPrintOctal ${argDate} 12
  # Checksum field needs blanks for calculating checksum.
  printf "%8.s" "">>"${tarFileName}"
  # Link indicator (file type)
  printf "0" >>"${tarFileName}"
  # UStar indicator and Version
  # Every reference I have seen says the version should be "00"
  # Thus printf "ustar\0%s" "00" gives the , a bit tricky
  # However, gnu tar is using "utar  \0" (spaces).
  # I am tried "00" and gnu tar did not complain.
  truncate -c -s $(( ${tarHdrOffset} + 257 )) "${tarFileName}"
  if [[ -n "$argLikeGnuTar" ]]; then
    # This is like GNU tar, pre-Posix
    printf "ustar  \0" >>"${tarFileName}"
  else
    printf "ustar\0%s" "00" >>"${tarFileName}"
  fi
  # User Name field 32 bytes
  truncate -c -s $(( ${tarHdrOffset} + 265 )) "${tarFileName}"
  printf "%s" ${userName:-${USER}} >>"${tarFileName}"
  # Group name field 32 bytes
  truncate -c -s $(( ${tarHdrOffset} + 297 )) "${tarFileName}"
  printf "%s" ${groupName:-`id -gn ${USER}`} >>"${tarFileName}"
  truncate -c -s %512 "${tarFileName}"
  # Now compute checksum and patch header
  checksum=$( dd status=none iflag=skip_bytes,count_bytes \
                skip=${tarHdrOffset} count=512 if="${tarFileName}" | sum -s )
  printf "%6.6o\0 " ${checksum/ */} | \
  dd conv=nocreat,notrunc status=none \
    iflag=count_bytes count=8 \
    oflag=seek_bytes seek=$(( ${tarHdrOffset} + 148 )) of="${tarFileName}"
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
unset argSource argTarget argHelp argListOnly argLong argError argUser \
  argGzip argTmp argFilter argMode argAnon argReplace userName groupName \
  userID groupID argDebug argLikeGnuTar argDate

argBlockSize=2048

# --user@([ =])*) argUser="${1/[ =]/ }"; ;;
shopt -s extglob
while [[ -n ${1} ]]; do
  case "${1,,}" in
    --list)           argListOnly=1; ;;
    --long)           argLong=1; argListOnly=1; ;;
     -f?(=*))         if [[ "$1" = "-f" ]]; then shift; fi
                      argTarget="${1#-f=}"; ;;
    --file?(=*))      if [[ "$1" = "--file" ]]; then shift; fi
                      argTarget="${1#--file=}"; ;;
    --user?(=*))      if [[ "$1" = "--user" ]]; then shift; fi
                      argUser="${1#--user=}"; ;;
    --source?(=*@*))  if [[ "$1" = "--source" ]]; then shift; fi
                      ;&
      *@*)            argTmp="${1#--source=}"
                      argUser="${argTmp/@*/}"
                      argSource="${argTmp/*@/}"
                      if [[ "$argUser" = "$argTmp" ]]; then
                        unset argUser
                      fi; ;;
    --prefix?(=*))    if [[ "$1" = "--prefix" ]]; then shift; fi
                      tarEntryPrefix="${1#--prefix=}"; ;;
    --filter?(=*))    if [[ "$1" = "--filter" ]]; then shift; fi
                      argFilter="${1#--filter=}"; ;;
    --setmode?(=*))   if [[ "$1" = "--setmode" ]]; then shift; fi
                      argMode="${1#--setmode=}"; ;;
    --setdate?(=*))  if [[ "$1" = "--setdate" ]]; then shift; fi
                     argDate="${1#--setdate=}"; ;;
    --anon*)          userName="spiffs"; groupName="Arduino"
                      userID=0; groupID=0; ;;
    --blocksize?(*=)) if [[ "$1" = "--blocksize" ]]; then shift; fi
                      argBlockSize=$(( ${1#--blocksize=} * 512 )); ;;
    --likegnu*)       argLikeGnuTar=1; argBlockSize=10240; ;;
    --gzip)           argGzip="gz"; ;;
    --replace)        argReplace=1; ;;
    --debug)          argDebug=1; ;;
    --help)           argHelp=1; ;;
    *) argHelp=1; argError="${argError}\nUnknown option: \"${1}\""; ;;
  esac
  if [[ -n ${1} ]]; then shift; fi
done

#+ echo ""

logVarError() {
  local str
  for i in "$@"; do
    eval str="${i}=\'\${${i}}\'"
    logError "$str"
  done
}

if [[ -n ${argDebug} ]]; then
  logVarError argSource argTarget argHelp argListOnly argLong argError argUser \
   argGzip argFilter argMode argAnon argReplace userName groupName userID \
   groupID argDate argDebug
fi


#
# Validate command line parameters
#
if [[ -n ${argMode} ]]; then
  if validOctalNumber "${argMode}"; then
    fileMode=0${argMode}
  else
    argHelp=1; argError="${argError}\n--setmode bad value. The value should be an octal number."
  fi
fi

if [[ -z ${argDate} ]]; then
  argDate=$(date +"%s")
else
  if ! validDecNumber "${argDate}"; then
    argHelp=1; argError="${argError}\n--setdate bad value. The value should be a decimal number of seconds."
  fi
fi

_Passwd="${argUser/*:/}"
_User="${argUser/:*/}"
if [[ -n ${_User} ]] && [[ ${_Passwd} = ${_User} ]]; then
  unset _Passwd
  echo -e -n "\nEnter host password for user '${_User}': " >&2
  read _Passwd
  echo -e -n "\r\e[1A\e[K" >&2 # CR, up 1 line, clear to end of line, stay
  argUser="${_User}:${_Passwd}"
fi
unset _Passwd _User
if [[ -n ${argUser} ]] && [[ "${argUser/:/}" = "$argUser" ]]; then
  argHelp=1; argError="${argError}\nPassword required, when specifing USER."
fi

if [[ -z ${argTarget} ]] && [[ -z ${argHelp} ]]; then
  argHelp=1; argError="${argError}\n--file parameter required."
fi
if [[ -n ${argListOnly} ]] && [[ -z ${argSource} ]]; then
  argHelp=1; argError="${argError}\n--source parameter required, when using --list."
fi

# if [[ $argBlockSize -gt 10240 ]]; then
#   argHelp=1; argError="${argError}\n--blocksize exceeds the maximum of 20, 512 byte records."
# fi

if [[ -n ${argHelp} ]]; then
  # if [[ -n ${argError} ]]; then
  #   echo -e "${argError}\n"
  # fi
  printUsage | less
  errorExit 1
fi

#
# Insure proper path endings, etc. for later.
tarEntryPrefix="${tarEntryPrefix%/}"

if ! validLinuxPath "${argTarget}"; then
  printFolded "***" "\nBad path/name, \"${argTarget}\"\n"
  errorExit 1
fi

# if [[ "${argTarget:0:2}" = "~/" ]]; then
if [[ "${argTarget:0:1}" = "~" ]]; then
  eval tarFileName="${argTarget}"
  if [[ "${tarFileName:0:1}" = "~" ]]; then
    printFolded "***" "\n"\
      "This path expression, \"${argTarget}\", did not expand to a valid path."\
      "Expanded form came back as \"${tarFileName}\""\
      "\n"
    errorExit 1
  fi
elif [[ "${argTarget:0:2}" = "./" ]]; then
  tarFileName="${argTarget#./}"
# elif [[ "${argTarget:0:1}" = "~" ]]; then
#   # ~~USER might be legal, however, it is more likely a typo so dissalow for now.
#   if [[ "${argTarget}" =~ ^~[^~/][^/]*/[^/].*$ ]]; then
#     eval target="${argTarget}"
#     if [[ "${target:0:1}" = "~" ]]; then
#       printFolded "***" "\n"\
#         "This path expression, \"${argTarget}\", did not expand to a valid path."\
#         "Expanded form came back as \"${target}\""\
#         "\n"
#       errorExit 1
#     fi
#   else
#     printFolded "***" "\n"\
#       "This was not a recognized path expression. Please try another."\
#       "\n"
#     errorExit 1
#   fi
#
elif [[ "${argTarget:0:1}" = "/" ]]; then
  # For safety sake assume "/" is an accident.
  printFolded "***" "\n"\
    "Bad directory name, \"${argTarget}\"."\
    "Cannot use file specification starting at the root of the filesystem,"\
    "\"/\"."\
    "Please run command from or above the directory level you wish to create"\
    "the archive file."\
    "\n"
  errorExit 1
else
  tarFileName="${argTarget}"
fi

tarFileNameBase="${tarFileName%.*}"
tarFileNameExt="${tarFileName##*.}"
if [[ "${tarFileNameExt}" = "tgz" ]]; then
  tarFileName="${tarFileNameBase}.tar"
  tarFileNameZ="${tarFileNameBase}.tgz"
  argGzip="tgz";
elif [[ -n "${argGzip}" ]]; then
  tarFileNameZ="${tarFileNameBase}.tgz"
else
  unset tarFileNameZ
fi

if [[ -f "${tarFileName}" ]]  ||
   [[ -f "${tarFileNameZ}" ]] ||
   [[ -f "${tarFileName}.gz"  ]]; then

  if [[ -n ${argReplace} ]]; then
    goit=1
  else
    echo -e "\n"\
      "If we continue, the following existing output and intermediate files\n"\
      "will be deleted or overwriten:\n" >&2
    [[ -f "${tarFileName}"    ]] && echo "  ${tarFileName}" >&2
    [[ -f "${tarFileNameZ}"   ]] && echo "  ${tarFileNameZ}" >&2
    [[ -f "${tarFileName}.gz" ]] && echo "  ${tarFileName}.gz" >&2
    echo -e -n "\nWould you like to continue (yes/no)? " >&2
    unset yesno
    gotit=-1
    for (( i=12; (i>0)&&(${gotit}<0); i-=1 )); do
      read yesno
      case "${yesno,,}" in
        yes) gotit=1;
             ;;
        no)  gotit=0;
             ;;
        *)   echo -n "Please type 'yes' or 'no': " >&2
             ;;
      esac
    done
    if [[ $gotit -lt 1 ]]; then
      echo ""
      exit 1
    fi
  fi
  [[ -f "${tarFileName}"    ]] && ! rm "${tarFileName}"     && gotit=0
  [[ -f "${tarFileNameZ}"   ]] && ! rm "${tarFileNameZ}"    && gotit=0
  [[ -f "${tarFileName}.gz" ]] && ! rm "${tarFileName}.gz"  && gotit=0
  if [[ $gotit -lt 1 ]]; then
    exit 1;
  fi
fi



if [[ "${tarFileName%/*}" != "${tarFileName}" ]] && ! [[ -d "${tarFileName%/*}" ]]; then
  printFolded "***" "\n"\
    "This path does not exist, \"${tarFileName%/*}\"."\
    "All of the folders in the path expression must already exist."\
    "\n"
  errorExit 1
fi
if [[ -z "${tarFileName}" ]]; then
  printFolded "***" "\nInternal error: \"target\" not set.\n"
  errorExit 1
fi


if [[ -n ${argSource} ]]; then
  if validNetworkName "${argSource}"; then
    httpTarget="http://${argSource}"
  else
    printFolded "***" "\nBad Network name, \"${argSource}\"\n"
    errorExit 1
  fi
else
  printFolded "***" "\n"\
    "Missing server name."\
    "\n"
  errorExit 1
fi


listFiles() {
  local matchCount=0
  if [[ -n ${argLong} ]]; then
    echo -e "File names|Size\n----------|----"
  fi
  for (( i=0; i<${#spiffsNames[@]}; i+=2 )); do
    if [[ -z ${argFilter} ]] || [[ "${spiffsNames[i]}" =~ ${argFilter} ]]; then
      matchCount=$(( $matchCount + 1 ))
      if [[ -n ${argLong} ]]; then
        echo -e "${spiffsNames[i]}|${spiffsNames[i+1]}"
      else
        echo "${spiffsNames[i]}"
      fi
    fi
  done
  if [[ -n ${argFilter} ]]; then
    echo "${matchCount} files matched filter, \"${argFilter}\""
  fi
}

findMatchCount(){
  local matchCount=0
  for (( i=0; i<${#spiffsNames[@]}; i+=2 )); do
    if [[ -z ${argFilter} ]] || [[ "${spiffsNames[i]}" =~ ${argFilter} ]]; then
      matchCount=$(( $matchCount + 1 ))
    fi
  done
  eval ${1}=${matchCount}
}

#
# download list
#
getList "${argUser}" "${tmpList}"
rc=$?
if [[ $rc -ne 0 ]]; then
  printFolded "***" "\n"\
    "Failed to get file list from \"${httpTarget}\"."\
    "\n"
  errorExit 1
fi

# spiffsNames=( `echo -n "${response}" | jq -r '.[] | select(.type=="file") | .name'` )
make_spiffsNames
if [[ $(( ${#spiffsNames[@]} % 2 )) -ne 0 ]]; then
  printFolded "***" "\nThe list of files to backup is corrupted.\n"
  errorExit 1
fi


#
# Handle listonly option
#
if [[ -n ${argListOnly} ]]; then
  listFiles | column -s\| -t
  exit 0
fi


#
# Download files and build tar file
#
echo -e "\nCreating nar backup of ${argSource}'s SPIFFS file system." \
        "\nResults will be written to: \"${tarFileName}\"."

touch "${tarFileName}" || errorExit 1


findMatchCount numOfFilesToBackup
numFilesBackedUp=0
echo ""
for (( i=0; i<${#spiffsNames[@]}; i+=2 )); do
  if [[ -z ${argFilter} ]] || [[ "${spiffsNames[i]}" =~ ${argFilter} ]]; then
    fileName="${tarEntryPrefix}/${spiffsNames[i]#/}"
    remoteFileName="${spiffsNames[i]}"
    fileSize=${spiffsNames[i+1]}
    echo -n -e "\rDownloading: $(( ${numFilesBackedUp} + 1 )) of"\
       "${numOfFilesToBackup} size ${fileSize}, name \"${spiffsNames[i]}\"\e[K"
    tarWriteHeader
    if downloadFile "${argUser}" "${tarFileName}"; then
      tarFileSize=$( stat --printf="%s" "${tarFileName}" )
      actualFileSize=$(( $tarFileSize - $tarHdrOffset - 512 ))
      if [[ -z "$fileSize" ]]; then
        fileSize=${actualFileSize}
      else
        estimateSize=$(( ${fileSize} + 512 + $tarHdrOffset ))
        if [[ ${tarFileSize} -ne ${estimateSize} ]]; then
          printFolded "***" "\n"\
            "Error downloading \"${fileName}\", downloaded size is"\
            "${actualFileSize} bytes."\
            "List operation reported ${fileSize} bytes."\
            "\n"
          errorExit 100
        fi
      fi
      numFilesBackedUp=$(( ${numFilesBackedUp} + 1 ))
    else
      truncate -c -s +1024 "${tarFileName}" # two records of zeros
      truncate -c -s %${argBlockSize} "${tarFileName}"
      printFolded "***" "\n"\
        "Error downloading file from ${httpTarget}"\
        "only ${numFilesBackedUp} of ${#spiffsNames[@]} were backed up." \
        "\n"
      errorExit 1
    fi
  fi
done

echo -e -n "\r\e[K"
if [[ -n ${argFilter} ]]; then
  echo -e "Using --filter=\"${argFilter}\""
fi
echo -e "Downloaded: ${numFilesBackedUp} of ${numOfFilesToBackup} files from ${argSource}."

# For the end of the archive there should be at least two record of 512 bytes
# of zero. The file should be expanded to an integral block size.
# Punt
truncate -c -s +1024 "${tarFileName}" # two records of zeros
truncate -c -s %${argBlockSize} "${tarFileName}"

if [[ -n ${argGzip} ]]; then
  gzip "${tarFileName}"
  mv ${tarFileName}.gz "${tarFileNameZ}"
  tarFileName="${tarFileNameZ}"
fi

echo ""
echo "Archive file \"${tarFileName}\" complete."
echo "Size $( stat --printf="%s" "${tarFileName}" ) bytes."
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
