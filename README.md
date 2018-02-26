# arduino-esp8266-spiffs-utils

Just one utility for now

```
->nar.sh --help


nar - Network ARchiver for Arduino ESP8266 web servers.

A simple bash script to download the SPIFFS filesystem files from an ESP8266
running an Arduino compatible sketch with Web Server. A UStar formated archive
(tar) file is created. The file names from the SPIFFS filesystem will have the
prefix "data" added to the beginning of the SPIFFS file names. If
the file name does not have a leading "/", one will be inserted. The last
modification time of an archived file, will be the time it was downloaded.


Usage:

  nar.sh

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
      "~/Downloads/<target folder name>/list". The options requires
      "--from".

    --target=FOLDER
      The name of the folder that will be created in the default directory,
      "~/Downloads". This folder is used to store the
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
```
