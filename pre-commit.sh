#!/bin/bash
#
# An example hook script to verify what is about to be committed.
# Called by "git commit" with no arguments.  The hook should
# exit with non-zero status after issuing an appropriate message if
# it wants to stop the commit.
#
# To enable this hook, rename this file to "pre-commit".
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

RVM=`rvm env --path --`
if [ $? ]; then
  source ${RVM}
fi


if git rev-parse --verify HEAD >/dev/null 2>&1
then
	against=HEAD
else
	# Initial commit: diff against an empty tree object
	against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

# If you want to allow non-ASCII filenames set this variable to true.
allownonascii=$(git config --bool hooks.allownonascii)

# Redirect output to stderr.
exec 1>&2

# Cross platform projects tend to avoid non-ASCII filenames; prevent
# them from being added to the repository. We exploit the fact that the
# printable range starts at the space character and ends with tilde.
if [ "$allownonascii" != "true" ] &&
	# Note that the use of brackets around a tr range is ok here, (it's
	# even required, for portability to Solaris 10's /usr/bin/tr), since
	# the square bracket bytes happen to fall in the designated range.
	test $(git diff --cached --name-only --diff-filter=A -z $against |
	  LC_ALL=C tr -d '[ -~]\0' | wc -c) != 0
then
	cat <<\EOF
Error: Attempt to add a non-ASCII file name.

This can cause problems if you want to work with people on other platforms.

To be portable it is advisable to rename the file.

If you know what you are doing you can disable this check using:

  git config hooks.allownonascii true
EOF
	exit 1
fi

# If there are whitespace errors, print the offending file names and fail.
git diff-index --check --cached $against --

err=0
msg=''

run(){
    tmp=$(mktemp -t cv-precommit)
    echo -n "Running ${@:3:2}: "
    "$@" >$tmp 2>&1
    ret=$?
    if [ $ret != 0 ]; then
        let "err = $err + $ret"
        msg="${msg}\n\t${@:3:2} failed"
        echo -e "${RED}FAILED${NC}"
        echo "Tried: ${@}"
        cat $tmp
        rm -f $tmp
    else
        echo -e "${GREEN}PASSED${NC}"
    fi
    return $ret
}

START_TIME=$SECONDS
run bundle exec rubocop
run bundle exec rake validate 2>&1
run bundle exec rake metadata_lint
run bundle exec rake build
run bundle exec rake spec
run bundle exec rake strings:generate

DURATION=$(($SECONDS - $START_TIME))
echo "pre-commit checks took ${DURATION} seconds."
echo

if [ ${err} != 0 ]; then
    echo -e "${RED}ERROR: Some checks failed.  Commit halted. [${err}]${NC}"
    echo -e "${RED}Failed Tests: ${msg}${NC}"
fi
exit ${err}
