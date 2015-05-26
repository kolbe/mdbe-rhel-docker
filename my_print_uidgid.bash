#!/bin/bash
awk -F: '$1=="mysql"{printf "%d:%d\n",$3,$4}' /etc/passwd
