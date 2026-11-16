#!/usr/bin/env bash

shfmt --language-dialect bash --write bin/* lib/* scripts/*
shfmt --language-dialect bats --write tests/*.bats
