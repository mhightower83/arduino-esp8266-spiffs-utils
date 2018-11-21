# arduino-esp8266-spiffs-utils

These scripts may modify critical security or system files on your computer. By downloading, copying, or using these scripts, you assume all risks from the proper or improper functioning of this software. Absolutely no warranties, express or implied, are provided including fitness for a particular use. You alone are responsible for determining whether this software will meet your needs and expectations! This software is provided as is. Examine the script carefully before proceeding!

Just one utility for now

# Note, this is a work in progress. Always verify your results. There are and always will be bugs!!!

```

nar - Network ARchiver for an Arduino ESP8266 with Web Server Running

A simple bash script that will download files from an ESP8266 and create a tar
formated archive file. The ESP8266 must be running a compatible Arduino sketch
with Web Server. The archive file created is of UStar format. The file names
from the SPIFFS filesystem will have the prefix "data" added to the
beginning of the SPIFFS file names. If the file name does not have a leading
"/", one will be inserted. The last modification time of an archived file,
will be the time this script was started.


Usage:

  nar.sh

    Basic command line format:
      nar.sh <archive file name> <Network location> <list of files> <optional>

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
      Defaults to "data"

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

```
