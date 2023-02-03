# TED-LIUM AHG Speech Recognition Baseline #

## Introduction ##

A Kaldi baseline model adapted to personal/non-clustering machines.

## Version Released ##

* s5_r1
  1. Revised from original egs/tedlium/s5_r1 script
  2. Using updated Kaldi library

* s5_r2
  1. A tutorial example for undergraduate students
  2. Based on AISHELL-1 framework
  3. Using TED-LIUM 1 corpus

## TODO ##

1. To enable GPU exclusive mode via command "sudo nvidia-smi -c 3"
2. Type "screen" in command prompt to enter background process
3. cd s5_r2
4. Configure the variable exactDataDir in path.sh (The desired dataset location)
5. bash run.sh

## Learning Objectives ##

These are several hints for you to prepare your in-lab meeting presentation.

* Basic
  1. Which type of features are used?
  2. Overall model building flow (To explain each step)
  3. Arguments of each line of code (file I/O)
  4. How to decode other wave files
  5. How to know the overall performance

* Intermediate
  1. To visualize features (MFCC files, ivectors)
  2. To decode graph, decision trees
  3. Knowing the structure of neural networks
