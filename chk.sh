#!/bin/bash

wsm=./opt.wasm
wsm=./sigmoid.wasm

float2bin32le() {
	ifun='import functools;'
	isys='import sys;'
	iopr='import operator;'
	istr='import struct;'

	imports="${ifun} ${isys} ${iopr} ${istr}"

	python3 -c "${imports}"' functools.reduce(
    lambda state, f: f(state),
    [
      float,
      struct.Struct("<f").pack,
      sys.stdout.buffer.write,
    ],
    sys.stdin.read(),
  )'
}

result4human() {
	ifun='import functools;'
	isys='import sys;'
	iopr='import operator;'
	istr='import struct;'

	imports="${ifun} ${isys} ${iopr} ${istr}"

	sdef='s = struct.Struct("<f");'

	python3 -c "${imports} ${sdef}"' functools.reduce(
    lambda state, f: f(state),
    [
      s.unpack,
      operator.itemgetter(0),
      print,
    ],
    sys.stdin.buffer.read(4),
  )'
}

f2sig() {
	local f
	f=$1
	readonly f

	export F=$f
	python3 -c 'import os; import math; x=float(os.getenv("F")); print(1.0/(1.0+math.exp(-x)))'
}

echo approx version:
(
	echo -8.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo -4.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo -3.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo -2.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo -1.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 0.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 1.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 2.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 3.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 4.0 | float2bin32le | wazero run "${wsm}" | result4human
	echo 8.0 | float2bin32le | wazero run "${wsm}" | result4human
) | cat -n
echo

echo exact version:
(
	f2sig -8.0
	f2sig -4.0
	f2sig -3.0
	f2sig -2.0
	f2sig -1.0
	f2sig 0.0
	f2sig 1.0
	f2sig 2.0
	f2sig 3.0
	f2sig 4.0
	f2sig 8.0
) | cat -n
