#!/bin/bash
PATH=/home/galicaster/bin:/home/galicaster/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin


# First, check whether Galicaster is busy recording or not
# Get galicaster status as per OC endpoint
rest_user=`cat /usr/share/galicaster/conf-dist.ini | awk '/username/ -F'' { print $3 }'`
rest_pass=`awk 'f{print;f=0} /username/{f=1}' /usr/share/galicaster/conf-dist.ini | cut -f 2 -d '=' | sed 's/ //'`
admin_server=`awk '/host = http:\/\// { print $3}' /usr/share/galicaster/conf-dist.ini`
hostname=`cat /etc/hostname`
status=`curl --digest -u $rest_user:$rest_pass -H "X-Requested-Auth: Digest" -H "X-Opencast-Matterhorn-Authorization: true" -H "Accept: application/json" -H "Content-Type: application/json" -X GET  $admin_server/capture-admin/agents/$hostname.json | /home/galicaster/code/jq-linux64 '.' | grep '"state":' | awk -F':' '{ print $2 }' | awk -F'"' '{ print $2 }'`

if [ $status = "capturing" ];
then
	# Leave all alone and just exit, otherwise the recording will fail
	echo "$(date) - Program exited because we are capturing" >> /var/log/galicaster/workaround-script.log
	exit 0

elif [ $status = "idle" ];
then
	# Check whether a package is busy ingesting. Because the status during ingest is also idle,
	# the only way to do this is by tailing the log file and check if an ingest is ongoing
	# Check for the string "Ingesting MP" in the last 1000 lines of the log file
	
	#echo "$(date) - We have entered elif" >> /var/log/galicaster/workaround-script.log
	is_ingesting=`/usr/bin/tail -n1000 /var/log/galicaster/galicaster.log | grep -F "Ingesting MP" | awk -F' ' '{ print $6 }'`
	if [ "$is_ingesting" = "Ingesting" ]; # If you find a package that was ingesting, check whether that package has finished ingesting.
	then
		# Start by saving the MP ID if an ingest is ongoing
		mp_ingesting=`/usr/bin/tail -n1000 /var/log/galicaster/galicaster.log | grep -F "Ingesting MP" | awk -F' ' '{ print $8 }'`
		ingested=`/usr/bin/tail -n1000 /var/log/galicaster/galicaster.log | grep -F "Finalized Ingest for MP" | awk -F' ' '{ print $6 }'`
		mp_ingested=`/usr/bin/tail -n1000 /var/log/galicaster/galicaster.log | grep -F "Finalized Ingest for MP" | awk -F' ' '{ print $10 }'`
		if [ "$ingested" = "Finalized" ] && [ "$mp_ingesting" == "$mp_ingested" ];
		then
			# Delete the previous version of the lists file
			rm -rf /home/galicaster/broken-manifest.txt

			# Find all packages with broken manifest.xml files
			grep -i "mediapackage id" /home/galicaster/Repository/*/manifest.xml | awk -F':' '{ print $1 }' | awk -F'/' '{ print $5 }' > /home/galicaster/broken-manifest.txt
			
			# Check to see if there are any entries in the above file, i.e. any "broken" manifest.xml files
			if [ -s /home/galicaster/broken-manifest.txt ];
			then
			
				# Remove the ical first and then the mediapackage folder.

				rm -rf /home/galicaster/Repository/attach/calendar.ical
				sleep 5

				while read line 
				do
        				# Check to see whether any of these folders contains an avi file, if it does, leave it, if not, remove it
        				if [ ! -f /home/galicaster/Repository/$line/*.avi ]; 
					then
                				rm -rf /home/galicaster/Repository/$line
        				fi
				done < /home/galicaster/broken-manifest.txt
				# Now restart GC so that it will remove any remnants of broken wrong icals from memory
				/bin/sh /home/galicaster/restart_gc.sh
				echo "$(date) - Broken mediapackages were fixed and Galicaster was restarted." >> /var/log/galicaster/workaround-script.log
				exit 0

			else
				echo "$(date) - CA has finished ingesting, but the file 'broken-manifests.txt' was empty, so we did not have to do anything" >> /var/log/galicaster/workaround-script.log
				exit 0
			fi
		else
			echo "$(date) - MP $mp_ingesting was still busy ingesting, so we had to abort our plans" >> /var/log/galicaster/workaround-script.log
			exit 0
		fi
	# Execute this part if the CA is idle and not ingesting
	else
		# Delete the previous version of the lists file
		rm -rf /home/galicaster/broken-manifest.txt

		# Find all packages with broken manifest.xml files
		grep -i "mediapackage id" /home/galicaster/Repository/*/manifest.xml | awk -F':' '{ print $1 }' | awk -F'/' '{ print $5 }' > /home/galicaster/broken-manifest.txt

		# Check to see if there are any entries in the above file, i.e. any "broken" manifest.xml files
		if [ -s /home/galicaster/broken-manifest.txt ];
		then

			# Remove the ical first and then the mediapackage folder.

			rm -rf /home/galicaster/Repository/attach/calendar.ical
			sleep 5

			while read line 
			do
				# Check to see whether any of these folders contains an avi file, if it does, leave it, if not, remove it
				if [ ! -f /home/galicaster/Repository/$line/*.avi ];
				then
					rm -rf /home/galicaster/Repository/$line
				fi
				done < /home/galicaster/broken-manifest.txt
			# Now restart GC so that it will remove any remnants of broken wrong icals from memory
			/bin/sh /home/galicaster/restart_gc.sh
			echo "$(date) - Broken mediapackages were fixed and Galicaster was restarted." >> /var/log/galicaster/workaround-script.log
			exit 0
		fi
		echo "$(date) - CA is idle and not ingesting, but the file 'broken-manifests.txt' was empty, so we did not have to do anything" >> /var/log/galicaster/workaround-script.log
		exit 0
	

fi
else
	echo "$(date) - Capture agent was offline." >> /var/log/galicaster/workaround-script.log
	exit 0
fi
