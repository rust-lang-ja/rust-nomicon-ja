#!/bin/bash -e

cd $(git rev-parse --show-toplevel)

if ! mdbook -V > /dev/null 2>&1; then
    echo "Install mdbook by running 'cargo install mdbook --git https://github.com/azerupi/mdBook.git', "
    echo "and run this script again."

    exit 1
fi

mdbook build -d docs/
