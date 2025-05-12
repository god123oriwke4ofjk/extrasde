#!/bin/bash

cd ~/HyDE/Scripts
git pull origin master
./install.sh -r

cd ~/Extra
git pull
./install.sh
