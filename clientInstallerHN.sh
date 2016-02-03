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

    sleep 10
    unset IFS
    clusterhosts=$(curl -s -u $clusterUN:$clusterPS http://localhost:8080/api/v1/clusters/$clusterName/hosts|grep host_name|awk '{print $3}')
    clusterhosts=${clusterhosts//\"}
    clusterhosts=${clusterhosts/,/ }

data="{
       \"RequestInfo\":{
          \"command\":\"RESTART\",
          \"context\":\"Restart HDFS Client and YARN Client\",
          \"operation_level\":{
             \"level\":\"HOST\",
             \"cluster_name\":\"$clusterName\"
          }
       },
       \"Requests/resource_filters\":[
          {
             \"service_name\":\"YARN\",
             \"component_name\":\"YARN_CLIENT\",
             \"hosts\":\"$clusterhosts\"
          },
          {
             \"service_name\":\"HDFS\",
             \"component_name":"HDFS_CLIENT\",
             \"hosts\":\"$clusterhosts\"
          }
       ]
    }"

    curl -u $clusterUN:$clusterPS -H 'X-Requested-By: ambari' -X POST -d '$data' http://localhost:8080/api/v1/clusters/$clusterName/requests
fi