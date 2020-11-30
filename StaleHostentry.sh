#! /bin/bash

usage(){
echo -e "\nUsage: ./$(basename /tmp/scripts/StaleHostentry.sh)
where command `basename` provides script name to be executed. \n"
}

if [ "$1"  ==  "--help" ] || [ "$1"  ==  "-h" ]
then
usage
exit
fi


# Collect list of all hosts on Satellite.

curl --request GET --insecure -u exampleapiuser:$(cat ~/.secretfile ) https://satelliteserver.example.com/api/hosts?per_page=1150 | jq '.results[] | .provision_method + ", " + .subscription_facet_attributes.last_checkin + ", " + .content_facet_attributes.content_view.name + ", " + .certname' | egrep -v "virt-who" | sed 's/"//g' > /tmp/All_hosts.txt

# Run for loop to check which all VM are no longer in DNS record or not responding to Ping.

for i in `cat  /tmp/All_hosts.txt | cut -d , -f 4`; do ping -c 2 -w 2 $i >>/tmp/ping_response 2>&1; done

# Arranging list of hosts not available  in a different file lists (not responding to ping and no DNS record).

cat /tmp/ping_response | grep -B1 -i "100% packet loss" >> /tmp/host-not-responding.txt

cat /tmp/ping_response | grep "not known" | awk '{print $2}' | cut -d : -f1 >> /tmp/CompleteListofHostNotfound.txt
cat /tmp/host-not-responding.txt | grep -i "ping statistics"| cut -d " " -f2 >> /tmp/CompleteListofHostNotfound.txt


# Delete hosts based on the ping response result Or base on \
#"Name or service not known or 100% packet loss" and delete these hosts using hammer command

#For test/dry-run before removing Host, following hammer command can be used. Note, to uncomment this command and comment the command with delete option, before executing script.
#for i in `cat /tmp/CompleteListofHostNotfound.txt`; do { echo -e " \n Host getting removed from satellite $i \n" ; hammer host info --name $i |grep -i "FQDN" ; } >> /tmp/deleted_hosts.txt 2>&1; done

for i in `cat /tmp/CompleteListofHostNotfound.txt`; do { echo -e " \n Host getting removed from satellite $i \n" ; hammer host delete --name $i ; } >> /tmp/deleted_hosts.txt 2>&1; done


# Verify word count matched before and after removal -
#cat /tmp/CompleteListofHostNotfound.txt | wc -l
#cat /tmp/deleted_hosts.txt |wc -l

# Remove all files later
echo "List of Hosts removed" | mailx -s "List of Hosts removed" -a  /tmp/ping_response -a /tmp/CompleteListofHostNotfound.txt -a /tmp/deleted_hosts.txt user1-email@example.com

rm -rf /tmp/All_hosts.txt
rm -rf /tmp/ping_response
rm -rf /tmp/host-not-responding.txt
rm -rf /tmp/CompleteListofHostNotfound.txt
rm -rf /tmp/deleted_hosts.txt
