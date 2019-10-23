#!/bin/bash
export user="max" group="max"
envsubst '$user,$group' <./input/teamdrive@.service >./output/teamdrive@.service
envsubst '$user,$group' <./input/teamdrive_primer@.service >./output/teamdrive_primer@.service
envsubst '$user,$group' <./input/teamdrive_primer@.timer >./output/teamdrive_primer@.timer