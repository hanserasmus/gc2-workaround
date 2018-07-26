# gc2-workaround
Quick repo to help with workaround to the broken manifest.xml bug

##  Things to know before using this:

I used one special package called *jq* in my shell script's curl statement. This can be downloaded from [here](https://stedolan.github.io/jq/).

I don't see myself as a coder at all. So anyone can improve on this in any way they want. I have tested this for three scenarios basically:
  - If the CA is capturing, exit and do not do anything
  - If the CA is idle, but ingesting and has not finalised the ingest yet, exit and do nothing.
  - If the CA is idle, and not reference to an ingest was found in 1000 lines in the GC log, check to see if something needs fixing.
  
As I have stated, this is ugly, but it seems to work.
I am running this on a cron job every minute, but might lengthen that to 3 minutes, choice is yours.
