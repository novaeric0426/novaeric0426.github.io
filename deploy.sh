#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# 서브모듈 최신화
git submodule update --remote

# Hugo 빌드
hugo -t PaperMod --gc

# source 브랜치에 빌드 결과 push
cd public
git add .

msg="rebuild: $(date +"%Y-%m-%dT%H:%M:%S%z")"
if [ $# -eq 1 ]; then
  msg="$1"
fi
git commit -m "$msg"
git push origin source

# main 브랜치에도 반영
cd ..
git add .
if [ $# -eq 1 ]; then
  msg="$1"
fi
git commit -m "$msg"
git push origin main
