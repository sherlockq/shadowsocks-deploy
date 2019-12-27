#!/usr/bin/env bash
dns=`terraform output --json | jq -r '.public_ip.value[0]'`
ssh -t ubuntu@$dns