#!/bin/sh
set -e

cd /Users/as/Desktop/docu

rsync -a --delete --exclude='.git' jhd-source/4cp-simulator/ ai-workspace/4cp-simulator/
rsync -a --delete --exclude='.git' jhd-source/beiang8panel/ ai-workspace/beiang8panel/
rsync -a --delete --exclude='.git' jhd-source/887t25901_raaan_ala1/ ai-workspace/887t25901_raaan_ala1/

echo "WORK -> AI 同步完成"

