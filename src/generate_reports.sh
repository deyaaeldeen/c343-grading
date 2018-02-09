#!/bin/bash

## The script writes the result of compilation and execution to a a
## file named after the username of the student being graded in root
## of his cloned directory. The script groups failed to compile
## submissions in $ROOT/p<i>/failed. A list of student names with repo
## names not in the right form are listed in
## $ROOT/c343-invalid.txt. These need to be graded manually because
## the script can not infer their repo name.

# set -euo pipefail

# the submission deadline
DATE='Jan 26 2018 10:30 pm'
# lab = 0, homework = 1, project = 2
SUBMISSION_TYPE=2
SUBMISSION_INDEX=1
GRADEBOOK_PATH="students.csv"
# number of seconds to time out
ts=300

## -----------------------------------------------------------------------------
ROOT="/app"
PROJDIR="${ROOT}/gradespace"

# path to the exported csv file from the gradebook on Canvas
DATAFILE="${ROOT}/${GRADEBOOK_PATH}"

# path to the required JARs, such as junit
CLASSPATH="$ROOT"

# path to directory of the testsuite
TESTSUITE="${ROOT}/tests"

# path to the textfile that has a list of all students with compiling submissions
REPORTFILE="${PROJDIR}/reports.txt"

# path to the directory of compiling submissions
CLONESDIR="${PROJDIR}/clones"

# path to the textfile that has a list of students with not compiling submissions
ZEROSTUDENTSFILE="${PROJDIR}/failed.txt"

# path to the directory of not compiling submissions
FAILEDDIR="${PROJDIR}/failed/"

# path to the directory of missing submissions
MISSINGDIR="${PROJDIR}/missing/"

# path to the textfile that has a list of students who did not submit before the due date
LATESTUDENTSFILE="${PROJDIR}/late.txt"

# path to the textfile that contains a list of students who does not have a proper repository name
INVALIDFILE="${ROOT}/c343-invalid.txt"

rm -rf "$REPORTFILE" "$ZEROSTUDENTSFILE" "$FAILEDDIR" "$MISSINGDIR" "$CLONESDIR" "$LATESTUDENTSFILE" "$INVALIDFILE"
mkdir -p "$FAILEDDIR" "$CLONESDIR" "$MISSINGDIR"

_SILENT_JAVA_OPTIONS="$_JAVA_OPTIONS"
unset _JAVA_OPTIONS
alias java='java "$_SILENT_JAVA_OPTIONS"'

read_csv_field ()
{
    local student="$1";shift
    local ind="$1";    shift
    sed -E 's/("[^",]+),([^",]+")/\1###\2/g' "$DATAFILE" | awk -v v=$ind -v u=$student -F, '$3 == u {print $v}' | sed 's/###/,/g';
}

# submission_type: 0 is lab, 1 is homework, 2 is project
function get_src_paths ()
{
    local submission_type="$1"; shift
    local submission_index="$1"; shift
    local student_dir="$1"; shift

    local type_pattern=""
    
    if [ "$submission_type" -eq 0 ]
    then
	type_pattern="lab"
    elif [ "$submission_type" -eq 1 ]
    then
	type_pattern="hw|homework|hmwrk|assignment|assign|ass"
    elif [ "$submission_type" -eq 2 ]
    then
	type_pattern="p|project"
    else
	echo "bad submission_type val: " "$submission_type"
	exit -1
    fi
    RETURN=($(find  "$student_dir" -type f -name "*.java" | grep -E "(${type_pattern}).?${submission_index}.*.java"))
}

function get_src_dir ()
{
    local submission_type="$1"; shift
    local submission_index="$1"; shift
    local student_dir="$1"; shift

    # rename all directories with spaces to underscores
    find -name "* *" -print0 | sort -rz | \
	while read -d $'\0' f; do mv "$f" "$(dirname "$f")/$(basename "${f// /_}")"; done

    local type_pattern=""
    
    if [ "$submission_type" -eq 0 ]
    then
	type_pattern="lab"
    elif [ "$submission_type" -eq 1 ]
    then
	type_pattern="hw|homework|hmwrk|assignment|assign|ass"
    elif [ "$submission_type" -eq 2 ]
    then
	type_pattern="p|project"
    else
	echo "bad submission_type val: " "$submission_type"
	exit -1
    fi
    RETURN=$(find . -type d -print | grep -E "(${type_pattern}).?${submission_index}" | head -n1)
}

function main ()
{
    # add the github ssh key to the keychain to remember it.
    eval $(ssh-agent)
    ssh-add id_rsa
    
    s=($(cut -d, -f4 "$DATAFILE" | sed 1,2d | awk -F= '{print $1}'))

    for i in "${s[@]}"; do
	cd "$CLONESDIR"
	fullname=$(read_csv_field $i 1)
	repo="git@github.iu.edu:C343-Spring2018/C343-$i.git"
	git ls-remote "$repo" -q > /dev/null 2>&1
	if [ $? = "0" ]; then
	    git clone "$repo" "$i" -q > /dev/null 2>&1
	    cd "$i";
	    get_src_dir "$SUBMISSION_TYPE" "$SUBMISSION_INDEX" "${CLONESDIR}/${i}"
	    if [[ $(git log --since="$DATE" "${RETURN}") ]]; then
		echo "checking ${i},${fullname} (late)"
		## $(date -j -f '%b %d %Y %I:%M %p' -v+7d "$DATE" +'%b %d %Y %I:%M %p')
		LATE_DATE=$(date '+%b %d %Y %I:%M %p' -d "$DATE+7 days")
		git checkout `git rev-list -1 --before="$LATE_DATE" master` -q > /dev/null 2>&1
		echo $i,"$fullname" >> "$LATESTUDENTSFILE"
		echo "Late: Yes" >> "${CLONESDIR}/${i}/${i}.txt"
	    else
		echo "checking ${i},${fullname}"
		# checkout the last commit before the due date
		git checkout `git rev-list -1 --before="$DATE" master` -q > /dev/null 2>&1
		echo $i,"$fullname" >> "$REPORTFILE"
		echo "Late: No" >> "${CLONESDIR}/${i}/${i}.txt"
	    fi
	    printf "$i,${fullname}" >> "${CLONESDIR}/${i}/${i}.txt"
	    grading_dir="${CLONESDIR}/${i}/grading"
	    mkdir "$grading_dir"
	    local missing_flag=1
	    get_src_paths "$SUBMISSION_TYPE" "$SUBMISSION_INDEX" "${CLONESDIR}/${i}"
	    for src_path in "${RETURN[@]}"; do
		echo "$src_path"
		cp "$src_path" "$grading_dir"
		missing_flag=0
	    done
	    cp -R "${TESTSUITE}/." "$grading_dir"
	    cd "$grading_dir"
	    # remove the package line in the source files if exists
	    sed -i.bak '/package .*;/d' *.java
	    sleep 1
	    local failed_flag=0
	    printf "\n\n--------------------------------------------------------\n\nCompilation output\n\n" >> "${CLONESDIR}/${i}/${i}.txt"
	    javac -cp ".:${CLASSPATH}/junit-4.12.jar:${CLASSPATH}/hamcrest-core-1.3.jar" *.java >> "${CLONESDIR}/${i}/${i}.txt" 2>&1
	    if [ $? = "0" ]; then
		# submission compiles? great! let's check what you got
		testsuites=($(grep -rnw --include \*.java -l -e "import org.junit.Test;" . | xargs -L 1 basename))
		for testsuite in "${testsuites[@]}"; do
		    testsuite_no_ext=${testsuite%.*}
		    printf "\n\n--------------------------------------------------------\n\nRun-time output for ${testsuite} output\n\n" >> "${CLONESDIR}/${i}/${i}.txt"
		    timeout -s KILL ${ts}s java -cp ".:${CLASSPATH}/junit-4.12.jar:${CLASSPATH}/hamcrest-core-1.3.jar" org.junit.runner.JUnitCore "$testsuite_no_ext" >> "${CLONESDIR}/${i}/${i}.txt" 2>&1
		done
	    else
		failed_flag=1
	    fi
	    if [ "$failed_flag" -eq 1 ]; then
	    	# submission does not compile? well, too bad!
		echo $i,"$fullname" >> "$ZEROSTUDENTSFILE"
		cd "$CLONESDIR"
		mv "${CLONESDIR}/${i}" "${FAILEDDIR}/"
	    elif [ "$missing_flag" -eq 1 ]; then
		echo $i,"$fullname" >> "$ZEROSTUDENTSFILE"
		cd "$CLONESDIR"
		mv "${CLONESDIR}/${i}" "${MISSINGDIR}/"
	    fi
	else
	    echo "checking ${i},${fullname} (missing repo)"
	    echo $i,"$fullname" >> "$INVALIDFILE"
	fi
    done
}

main "$@"
