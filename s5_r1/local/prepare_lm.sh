#!/usr/bin/env bash
#
# Copyright  2014 Nickolay V. Shmyrev
# Apache 2.0


if [ -f path.sh ]; then . ./path.sh; fi

arpa_lm=$exactDataDir/cantab-TEDLIUM/cantab-TEDLIUM-pruned.lm3
[ ! -f $arpa_lm ] && echo No such file $arpa_lm && exit 1;

rm -rf data/lang_nosp_test
cp -r data/lang_nosp data/lang_nosp_test

# mdf
# Argument is out-of-order
arpa2fst --disambig-symbol=#0 \
  --read-symbol-table=data/lang_nosp_test/words.txt $arpa_lm  data/lang_nosp_test/G.fst


echo  "$0: Checking how stochastic G is (the first of these numbers should be small):"
fstisstochastic data/lang_nosp_test/G.fst

utils/validate_lang.pl data/lang_nosp_test || exit 1;

if [ ! -d data/lang_nosp_rescore ]; then

  big_arpa_lm=$exactDataDir/cantab-TEDLIUM/cantab-TEDLIUM-unpruned.lm4
  [ ! -f $big_arpa_lm ] && echo No such file $big_arpa_lm && exit 1;

  # utils/build_const_arpa_lm.sh $big_arpa_lm data/lang_nosp_test data/lang_nosp_rescore || exit 1;
  
  arpa2fst --disambig-symbol=#0 \
  --read-symbol-table=data/lang_nosp_test/words.txt $big_arpa_lm  data/lang_nosp_rescore/G.fst

fi

exit 0;
