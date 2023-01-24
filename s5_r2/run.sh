#!/usr/bin/env bash
#
# Based mostly on the Switchboard recipe. The training database is TED-LIUM,
# it consists of TED talks with cleaned automatic transcripts:
#
# http://www-lium.univ-lemans.fr/en/content/ted-lium-corpus
# http://www.openslr.org/resources (Mirror).
#
# Note: this only trains on the tedlium-1 data, there is now a second
# release which we plan to incorporate in a separate directory, e.g
# s5b or s5-release2.
#
# The data is distributed under 'Creative Commons BY-NC-ND 3.0' license,
# which allow free non-commercial use, while only a citation is required.
#
# Copyright  2014  Nickolay V. Shmyrev
#            2014  Brno University of Technology (Author: Karel Vesely)
#            2016  Johs Hopkins University (Author: Daniel Povey)
# Apache 2.0
#

. ./cmd.sh
. ./path.sh

nj=10
decode_nj=8

stage=10

. utils/parse_options.sh  # accept options.. you can run this run.sh with the
                          # --stage option, for instance, if you don't want to
                          # change it in the script.

# Data preparation
if [ $stage -le 0 ]; then
  local/download_data.sh || exit 1;

  local/prepare_data.sh || exit 1;

  local/prepare_dict.sh || exit 1;

  utils/prepare_lang.sh data/local/dict_nosp \
    "<unk>" data/local/lang_nosp data/lang_nosp || exit 1;

  local/prepare_lm.sh || exit 1;

fi

# Feature extraction
if [ $stage -le 1 ]; then
  for set in test dev train; do
    dir=data/$set
    steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" $dir $dir/log $dir/data || exit 1;
    steps/compute_cmvn_stats.sh $dir $dir/log $dir/data || exit 1;
  done
fi

# Now we have 118 hours of training data.
# Let's create a subset with 10k short segments to make flat-start training easier:
if [ $stage -le 2 ]; then
  utils/subset_data_dir.sh --shortest data/train 10000 data/train_10kshort || exit 1;
  utils/data/remove_dup_utts.sh 10 data/train_10kshort data/train_10kshort_nodup || exit 1;
fi

# Train
if [ $stage -le 3 ]; then
  # train mono
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" \
    data/train_10kshort_nodup data/lang_nosp exp/mono0a || exit 1;

  # decode mono
  utils/mkgraph.sh data/lang_nosp_test exp/mono0a exp/mono0a/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/mono0a/graph_nosp data/dev exp/mono0a/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/mono0a/graph_nosp data/test exp/mono0a/decode_nosp_test || exit 1
fi


if [ $stage -le 4 ]; then
  # align monophones
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono0a exp/mono0a_ali || exit 1;
  
  # train tri1
  steps/train_deltas.sh --cmd "$train_cmd" \
    2500 30000 data/train data/lang_nosp exp/mono0a_ali exp/tri1 || exit 1;

  # decode tri1
  utils/mkgraph.sh data/lang_nosp_test exp/tri1 exp/tri1/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri1/graph_nosp data/dev exp/tri1/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri1/graph_nosp data/test exp/tri1/decode_nosp_test || exit 1
fi

# New tri2 based on AISHELL receipe
if [ $stage -le 5 ]; then
  # align tri1
  steps/align_si.sh --cmd "$train_cmd" --nj 10 \
   data/train data/lang_nosp exp/tri1 exp/tri1_ali || exit 1;

  # train tri2 [delta+delta-deltas]
  steps/train_deltas.sh --cmd "$train_cmd" \
   2500 20000 data/train data/lang_nosp exp/tri1_ali exp/tri2 || exit 1;

  # decode tri2
  utils/mkgraph.sh data/lang_nosp_test exp/tri2 exp/tri2/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri2/graph_nosp data/dev exp/tri2/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri2/graph_nosp data/test exp/tri2/decode_nosp_test || exit 1

fi

# Newly-defined tri3 
if [ $stage -le 6 ]; then
  # align tri2
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri2 exp/tri2_ali || exit 1;
  # Train the second triphone pass model tri3a on LDA+MLLT features.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    4000 50000 data/train data/lang_nosp exp/tri2_ali exp/tri3 || exit 1;

  # Decode tri3
  utils/mkgraph.sh data/lang_nosp_test exp/tri3 exp/tri3/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri3/graph_nosp data/dev exp/tri3/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri3/graph_nosp data/test exp/tri3/decode_nosp_test || exit 1
fi

if [ $stage -le 7 ]; then
  # Align tri3 with fMLLR
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
   data/train data/lang_nosp exp/tri3 exp/tri3_ali || exit 1;

  # Train the third triphone pass model tri4a on LDA+MLLT+SAT features.
  # From now on, we start building a more serious system with Speaker
  # Adaptive Training (SAT).
  steps/train_sat.sh --cmd "$train_cmd" \
   2500 20000 data/train data/lang_nosp exp/tri3_ali exp/tri4 || exit 1;

  # Decode tri4
  utils/mkgraph.sh data/lang_nosp_test exp/tri4 exp/tri4/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri4/graph_nosp data/dev exp/tri4/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri4/graph_nosp data/test exp/tri4/decode_nosp_test || exit 1
fi


if [ $stage -le 9 ]; then
  # align tri4 with fMLLR
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
   data/train data/lang_nosp exp/tri4 exp/tri4_ali;

  # Train tri5, which is LDA+MLLT+SAT
  # Building a larger SAT system. You can see the num-leaves is 3500 and tot-gauss is 100000
  steps/train_sat.sh --cmd "$train_cmd" \
   3500 100000 data/train data/lang_nosp exp/tri4_ali exp/tri5 || exit 1;
  
  # decode tri5
  utils/mkgraph.sh data/lang_nosp_test exp/tri5 exp/tri5/graph_nosp || exit 1;
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri5/graph_nosp data/dev exp/tri5/decode_nosp_dev || exit 1
  steps/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
    --num-threads 4 \
    exp/tri5/graph_nosp data/test exp/tri5/decode_nosp_test || exit 1
fi

# Cahin model
if [ $stage -le 10 ]; then
  # align tri5a with fMLLR
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
   data/train data/lang_nosp exp/tri5 exp/tri5_ali || exit 1;

  # Train the TDNN
  local/chain/run_tdnn.sh
fi 


# Summary panel
# TODO
for x in exp/*/decode_nosp_test; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null
for x in exp/*/*/decode_nosp_test; do [ -d $x ] && grep WER $x/cer_* | utils/best_wer.sh; done 2>/dev/null

exit 0
