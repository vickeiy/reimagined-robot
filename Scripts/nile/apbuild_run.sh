sudo docker run -d --name $1  -h $1 --cpus="4.0" -v /home/vikpatel:/root -it 374188005532.dkr.ecr.us-east-1.amazonaws.com/nileglobalsw/apbuild:$2 bash

