#!/usr/bin/env bash

clusterUN=$1
clusterPS=$2
clusterName=$3
wasbURI=$4
edgeNodeIP=$5

# Import the helper method module.
wget -O /tmp/HDInsightUtilities-v01.sh -q https://hdiconfigactions.blob.core.windows.net/linuxconfigactionmodulev01/HDInsightUtilities-v01.sh && source /tmp/HDInsightUtilities-v01.sh && rm -f /tmp/HDInsightUtilities-v01.sh

wget https://github.com/psf/azureARMFusion/blob/master/fusion-hdi-2.2.8-client-hdfs_2.6.6-SNAPSHOT-1548_all.deb\?raw\=true -O /tmp/hdi-client.deb

dpkg -i /tmp/hdi-client.deb

curl -s localhost:8080 > /dev/null
hn1=$?
if [[ $hn1 -eq 0 ]]; then
    # if on HN1
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName core-site "fusion.underlyingFs" "$wasbURI"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName core-site "fs.wasb.impl" "org.apache.hadoop.fs.azure.NativeAzureFileSystem"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName core-site "fs.AbstractFileSystem.fusion.impl" "com.wandisco.fs.client.FusionAbstractFs"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName core-site "fs.fusion.server" "$edgeNodeIP:8023"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName core-site "fs.fusion.impl" "com.wandisco.fs.client.FusionHcfs"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName yarn-site "fs.AbstractFileSystem.fusion.impl" "com.wandisco.fs.client.FusionAbstractFs"

    currentMapredCP=$(grep PWD /etc/hadoop/conf/mapred-site.xml | sed -e 's/<value>//g' -e 's#</value>##g#')
    currentMapredCP="$currentMapredCP:/opt/wandisco/fusion/client/lib/*"

    /var/lib/ambari-server/resources/scripts/configs.sh -u $clusterUN -p $clusterPS set localhost $clusterName mapred-site "mapreduce.application.classpath" "$currentMapredCP"


    sleep 10
    #unset IFS
    #clusterhosts=$(curl -s -u $clusterUN:$clusterPS http://localhost:8080/api/v1/clusters/$clusterName/hosts|grep host_name|awk '{print $3}')
    #clusterhosts=${clusterhosts//\"}
    #clusterhosts=$(echo $clusterhosts|sed -e 's/ /,/g' -e 's/,zk.*//g')

    #echo "CLUSTERHOSTS: $clusterhosts"

    #data="{
    #   \"RequestInfo\":{
    #      \"command\":\"RESTART\",
    #      \"context\":\"Restart HDFS Client\",
    #      \"operation_level\":{
    #         \"level\":\"HOST\",
    #         \"cluster_name\":\"$clusterName\"
    #      }
    #   },
    #   \"Requests/resource_filters\":[
    #      {
    #         \"service_name\":\"HDFS\",
    #         \"component_name\":\"HDFS_CLIENT\",
    #         \"hosts\":\"$clusterhosts\"
    #      }
    #   ]
    #}"
    #echo "DATA: $data"
    #curl -u $clusterUN:$clusterPS -H 'X-Requested-By: ambari' -X POST -d '$data' http://localhost:8080/api/v1/clusters/$clusterName/requests

    #stop
    curl -u $clusterUN:$clusterPS "localhost:8080/api/v1/clusters/$clusterName/services?" -X PUT -H 'Accept: application/json, text/javascript, */*; q=0.01' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'X-Requested-By: X-Requested-By' -H 'X-Requested-With: XMLHttpRequest' --data "{\"RequestInfo\":{\"context\":\"_PARSE_.STOP.ALL_SERVICES\",\"operation_level\":{\"level\":\"CLUSTER\",\"cluster_name\":\"$clusterName\"}},\"Body\":{\"ServiceInfo\":{\"state\":\"INSTALLED\"}}}"

    sleep 100

    #start
    curl -u $clusterUN:$clusterPS "localhost:8080/api/v1/clusters/$clusterName/services?" -X PUT -H 'Accept: application/json, text/javascript, */*; q=0.01' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'X-Requested-By: X-Requested-By' -H 'X-Requested-With: XMLHttpRequest' --data "{\"RequestInfo\":{\"context\":\"_PARSE_.START.ALL_SERVICES\",\"operation_level\":{\"level\":\"CLUSTER\",\"cluster_name\":\"$clusterName\"}},\"Body\":{\"ServiceInfo\":{\"state\":\"STARTED\"}}}"

fi