#!/bin/bash

# default config
node="FullNode"
jar_path="."
conf_file="./config.conf"
tron_grep_filter="FullNode.jar"
http_grep_filter="SimpleHTTPServer"
database_dir_src="./output-directory"
database_dir_dest="/tmp/database"
http_host_port="0.0.0.0:18890"

while [ -n "$1" ] ;do
    case "$1" in
        --help)
            echo "bash dumpDbAndRestart.sh --node {node} --jar_path {jar_path} --dbsrc {dbsrc} --dbdst {dbdst} --conf_file {conf_file} --http_host_port {http_host_port}"
            exit 0
            ;;
        --node)
            node=$2
            shift 2
            ;;
        --http_host_port)
            APP=$2
            shift 2
            ;;
        --dbsrc)
            database_dir_src=$2
            shift 2
            ;;
        --dbdst)
            database_dir_dest=$2
            shift 2
            ;;
        --jar_path)
            jar_path=$2
            shift 2
            ;;
        --conf_file)
            conf_file=$2
            shift 2
            ;;
        *)
            ;;
    esac
done

echo "node    : $node"
echo "http_host_port        : $http_host_port"
echo "database_dir_src: $database_dir_src"
echo "database_dir_dest   : $database_dir_dest"
echo "jar_path: $jar_path"
echo "conf_file : $conf_file"

if [ ! -f "$jar_path/$node.jar" ]; then
   echo "$jar_path/$node.jar does not exist! Please Check!"
   exit 1
fi

if [ ! -f "$conf_file" ]; then
   echo "$conf_file does not exist! Please Check!"
   exit 1
fi

if [ ! -d "$database_dir_src" ]; then
  echo "The database source does not exist!"
  exit 1
fi

if [ ! -d "$database_dir_dest" ]; then
  mkdir "$database_dir_dest"
fi

if [ ! -d "$database_dir_dest" ]; then
  echo "The database destination does not exist!"
  exit 1
fi

database_name=${node}_output-directory.tgz
tron_pid=`ps -ef |grep $node.jar |grep -v grep |awk '{print $2}'`
if [ ! -n "$tron_pid" ]; then
  echo "The java-tron exited, Please start the java-tron!"
  exit 0
fi

while true;do
  output=$(ps -p "$tron_pid")
  if [ "$?" -eq 0 ]; then
    kill -15 $tron_pid
    echo "The java-tron process is exiting, it may take some time, forcing the exit may cause damage to the database, please wait patiently..."
    sleep 1
  else
    echo "java-tron killed successfully!"
    break
  fi
done

# tar the database file and calc the md5.
tar -czf $database_dir_dest/$database_name $database_dir_src >/dev/null 2>&1
md5sum $database_dir_dest/$database_name > $database_dir_dest/md5.txt

http_pid=`ps -ef |grep SimpleHTTPServer |grep -v grep |awk '{print $2}'`

while [ ! -n "$http_pid" ]; do
  echo "The SimpleHTTPServer is starting!"
  wget https://raw.githubusercontent.com/shydesky/MultithreadedSimpleHTTPServer/master/MultithreadedSimpleHTTPServer.py -O $database_dir_dest/MultithreadedSimpleHTTPServer.py
  nohup python -m $database_dir_dest/MultithreadedSimpleHTTPServer "$http_host_port" "$database_dir_dest"&
  http_pid=`ps -ef |grep $http_grep_filter |grep -v grep |awk '{print $2}'`
done

# restart the tron
if [ $node == "FullNode" ];then
  nohup java -Xmx12g -jar $jar_path/$node.jar -c $conf_file&
else
  nohup java -Xmx24g -jar $jar_path/$node.jar -c $conf_file&
fi

echo "Dump database and restart $node successfully!"
