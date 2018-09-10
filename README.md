# arduino-esp8266-spiffs-utils

These scripts may modify critical security or system files on your computer. By downloading, copying, or using these scripts, you assume all risks from the proper or improper functioning of this software. Absolutely no warranties, express or implied, are provided including fitness for a particular use. You alone are responsible for determining whether this software will meet your needs and expectations! This software is provided as is. Examine the script carefully before proceeding!

Just one utility for now

# Note, this is a work in progress (*ALPHA GRADE CODE*). There are and always will be bugs!!!

```

nar - Network ARchiver for Arduino ESP8266 web servers.

A simple bash script to download the SPIFFS filesystem files from an ESP8266
running an Arduino compatible sketch with Web Server. And create a UStar
formated archive (tar) file. The file names from the SPIFFS filesystem will have
the prefix "data" added to the beginning of the SPIFFS file names.
If the file name does not have a leading "/", one will be inserted. The last
modification time of an archived file, will be the time it was downloaded.


Usage:

  nar.sh

    Basic command line format:
      nar.sh  <archive file name>  <Network location>  <list of files>

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
        SERVER name would be the Network name (DNS, mDNS, ...) of the device
        with a SPIFFS to download.
          examples:
            mydevice.local
            admin:password@mydevice.local

     <list of files>  expression - optional
    --filter=REGEX
        examples:
          --filter="/w*"
          --filter="/w/*.gz"
          --filter="/w/[0-9]something.jpg"


      --listonly

  Supported options:

     -f=ARCHIVENAME        or
    --file=ARCHIVENAME
      ARCHIVENAME, the name of the archive file you are creating. Suggest
      using a ".tar" extension to make it easy to identify.

      [USER:PASSWORD@]SERVER
      Specify the [USER:PASSWORD@] part, when authentication is required.
      SERVER name would be the Network name (DNS, mDNS, ...) of the device
      with a SPIFFS to download.

    --list      (optional)
    --long
      "--list" will only list the files that would have be placed in archive
      file, dry run.
      "--long" is the same as "--list"; however, has the file lengths.

    --filter=REGEX  (optional)
      A regular expression filter to limit the files downloaded.
      Use with "--long to confirm what you have selected.

    --replace (optional)
      Overwrite an old backup.

    --prefix=PREFIX (optional)
      The file names from the SPIFFS filesystem will have the string PREFIX
      added to the beginning of the SPIFFS file names.
      The defaults is "data"

    --setmode=<access mode bits in octal> (optional)
      Defaults to 0664.

    --anon  (optional)
      By default, owner and group information recorded in the tar
      backup file is that of the account running the script.
      This option changes the owner to "spiffs" and the group to "Arduino".
      And, UID and GID are set to 0.

    --gzip (optional)
      Run gzip on the newly completed archive file.

    --help
      This usage message.

```
