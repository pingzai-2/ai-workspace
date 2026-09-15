#!/bin/sh
set -e

cd /Users/as/Desktop/docu

rsync -a --delete --exclude='.git' ai-workspace/4cp-simulator/ jhd-source/4cp-simulator/
rsync -a --delete --exclude='.git' ai-workspace/beiang8panel/ jhd-source/beiang8panel/
rsync -a --delete --exclude='.git' ai-workspace/887t25901_raaan_ala1/ jhd-source/887t25901_raaan_ala1/

echo "AI -> WORK 同步完成"

