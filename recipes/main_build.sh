#!/usr/bin/env bash
set -e

echo "buildMode: $buildMode"

if [ "$buildMode" = "docker_singularity" ]; then
       echo "starting local docker build:"
       echo "---------------------------"
       sudo docker build -t ${imageName}:$buildDate -f  ${imageName}.Dockerfile .
       # https://medium.com/@artur.klauser/building-multi-architecture-docker-images-with-buildx-27d80f7e2408
       # https://github.com/gentoo/gentoo-docker-images/issues/98#issuecomment-735392789
       # export DOCKER_CLI_EXPERIMENTAL=enabled
       # docker buildx create --use --append --name insecure-builder4 --buildkitd-flags '--allow-insecure-entitlement security.insecure'
       # docker buildx build --allow security.insecure -t ${imageName}:$buildDate -f ${imageName}.Dockerfile .

       if [ "$testImageDocker" = "true" ]; then
              echo "tesing image in docker now:"
              echo "---------------------------"
              sudo docker run -it ${imageName}:$buildDate
       fi

       echo "uploading docker image now:"
       echo "---------------------------"
       sudo docker tag ${imageName}:$buildDate vnmd/${imageName}:$buildDate

       echo "====================================================="
       echo "run docker login if never logged in on that box:"
       echo "sudo docker login"
       echo "====================================================="

       sudo docker push vnmd/${imageName}:$buildDate
       sudo docker tag ${imageName}:$buildDate vnmd/${imageName}:latest
       sudo docker push vnmd/${imageName}:latest
fi

if [ "$buildMode" = "docker_local" ]; then
       echo "starting local docker build:"
       echo "---------------------------"
       sudo docker build -t ${imageName}:$buildDate -f  ${imageName}.Dockerfile .

       if [ "$testImageDocker" = "true" ]; then
              echo "tesing image in docker now:"
              echo "---------------------------"
              sudo docker run -it ${imageName}:$buildDate
       fi

       echo "uploading docker image now:"
       echo "---------------------------"
       sudo docker tag ${imageName}:$buildDate vnmd/${imageName}:$buildDate

       echo "====================================================="
       echo "run docker login if never logged in on that box:"
       echo "sudo docker login"
       echo "====================================================="

       sudo docker push vnmd/${imageName}:$buildDate
       sudo docker tag ${imageName}:$buildDate vnmd/${imageName}:latest
       sudo docker push vnmd/${imageName}:latest
fi

if [ "$buildMode" = "docker_hub" ]; then
       echo "Generating docker recipe:"
       echo "---------------------------"
fi

if [ "$buildMode" = "docker_singularity" ]; then
        echo "BootStrap:docker" > ${imageName}.Singularity
        echo "From:vnmd/${imageName}" >> ${imageName}.Singularity
        echo "" >> ${imageName}.Singularity
        echo "%labels" >> ${imageName}.Singularity
        echo "OWNER Steffen.Bollmann@cai.uq.edu.au" >> ${imageName}.Singularity
        echo "Build-date $buildDate" >> ${imageName}.Singularity
        echo "NAME $imageName" >> ${imageName}.Singularity
        echo "Description $imageName" >> ${imageName}.Singularity
        echo "VERSION $buildDate" >> ${imageName}.Singularity           
fi

if [[ -f ${imageName}_${buildDate}.sif ]] || [[ -d ${imageName}_${buildDate}.sif ]] ; then
       echo "removing old local image file:"
       echo "----------------------"
       sudo rm -rf ${imageName}_${buildDate}.sif
fi

if [ "$remoteSingularityBuild" = "true" ]; then
       echo "====================================================="
       echo "singularity remote login has to be done every 30days:"
       echo "singularity remote login"
       echo "====================================================="
       echo "starting remote build:"
       echo "----------------------"
       singularity build --remote ${imageName}_${buildDate}.sif ${imageName}.Singularity
fi


if [ "$localSingularityBuild" = "true" ]; then
       echo "starting local build:"
       echo "----------------------"
       sudo singularity build ${imageName}_${buildDate}.sif ${imageName}.Singularity
fi


if [ "$localSingularityBuildWritable" = "true" ]; then
       echo "starting local build for development purposes with a writable image file:"
       echo "----------------------"
       sudo singularity build --sandbox ${imageName}_${buildDate}.sif ${imageName}.Singularity
fi


if [ "$testImageSingularity" = "true" ]; then
       echo "testing singularity image:"
       echo "----------------------"
       sudo singularity shell --bind $PWD:/data ${imageName}_${buildDate}.simg
fi

if [[ "$uploadToSwift" = "true" && "$localSingularityBuildWritable" = "false" ]]; then
       echo "uploading image to swift storage:"
       echo "----------------------"
       source ../../setupSwift.sh
       swift upload singularityImages ${imageName}_${buildDate}.sif --segment-size 1073741824  
fi

if [ "$uploadToSylabs" = "true" ]; then
       echo "====================================================="
       echo "singularity remote login has to be done every 30days:"
       echo "singularity remote login"
       echo "====================================================="

       echo "sign image:"
       echo "create keypair if necessary: singularity key newpair"
       singularity sign -k 2 ${imageName}_${buildDate}.sif

       echo "uploading image to sylabs registry:"
       echo "----------------------"
       singularity push ${imageName}_${buildDate}.sif library://sbollmann/vnmd/${toolName}:${toolVersion}_${buildDate}

       echo "container uploaded - it can now be found via:"
       echo "singularity search ${imageName}"
       echo "and pull via:"
       echo "singularity pull ${imageName}_${buildDate}.sif library://sbollmann/vnmd/${toolName}:${toolVersion}_${buildDate}"
fi

# git commit -am 'auto commit after build run'
# git push

if [[ "$cleanupSif" = "true" && "$localSingularityBuildWritable" = "false" ]]; then
       mv ${imageName}_${buildDate}.sif ../../container_built/
fi
