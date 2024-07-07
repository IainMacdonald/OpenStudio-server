#!/bin/bash -e
cd ../..
docker stack rm osserver || true
while [ $(docker ps -q | wc -l) != 1 ]; do sleep 5; done
sleep 5
docker volume rm -f osdata || true
docker volume rm -f dbdata || true
#docker image rm 127.0.0.1:5000/openstudio-server -f
docker build . -t="127.0.0.1:5000/openstudio-server" --build-arg OPENSTUDIO_VERSION=3.7.0
docker push 127.0.0.1:5000/openstudio-server
cd docker/R
#docker image rm 127.0.0.1:5000/openstudio-rserve -f
docker build . -t="127.0.0.1:5000/openstudio-rserve"
docker push 127.0.0.1:5000/openstudio-rserve
docker pull mongo:6.0.7
docker tag mongo:6.0.7 127.0.0.1:5000/mongo
docker push 127.0.0.1:5000/mongo
docker pull redis:6.0.9
docker tag redis:6.0.9 127.0.0.1:5000/redis
docker push 127.0.0.1:5000/redis
docker pull public.ecr.aws/aws-ec2/amazon-ec2-metadata-mock:v1.11.2
docker tag public.ecr.aws/aws-ec2/amazon-ec2-metadata-mock:v1.11.2 127.0.0.1:5000/amazon-ec2-metadata-mock
docker push 127.0.0.1:5000/amazon-ec2-metadata-mock
cd ../../local_setup_scripts/win64
docker stack deploy osserver --compose-file=docker-compose-mock.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
#docker service update --restart-condition none osserver_worker
docker service scale osserver_worker=2
echo 'osserver stack rebuilt and redeployed'
