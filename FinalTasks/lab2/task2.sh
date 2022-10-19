#! /bin/bash

jsonfile="output.json"
inputfile=$1
first_line=$(head -n 1 $inputfile)

# Array of statuses
declare -A status_array
# Array of durations
declare -A duration_array

########################################################
# Functions:

# Getting a value of testName.
function fun_get_testName() {
    OLD_IFS=$IFS
    IFS=',' read -r -a array <<<$first_line
    local testName="${array[0]//[/}"
    testName="${testName//]/}"
    testName=$(echo $testName | xargs)
    IFS=$OLD_IFS
    echo $testName
}

# Getting count of tests
function fun_get_count_tests() {
    local NUM=${first_line/*../}
    local COUNT_TESTS=${NUM/ */}
    echo $COUNT_TESTS
}

# Getting a test's status
# Input data: string_test
function fun_get_test_status {
    local substr="ok"
    local prefix=${string_test%%$substr*}
    local index=${#prefix}
    local result=false
    if [[ index -eq 0 ]]; then
        result=true
    fi
    echo $result
}

# Getting a test's duration
# Input data: string_test
function fun_get_duration {
    local words=($string_test)
    local index_last_element=${#words[@]}
    index_last_element=$((index_last_element - 1))
    echo "${words[$index_last_element]}"
}

# Getting a test's name
# Input data: string_test, CURRENT_INDEX, duration
function fun_get_name_of_test {
    local search="$CURRENT_INDEX"
    local prefix=${string_test%%$search*}
    local length="${#string_test}"
    local start=$((${#prefix} + ${#search} + 1))
    search="$duration"
    local end=$((${length} - ${#search} - 2))
    local result_string=$(cut -c${start}-${end} <<<$string_test)
    result_string=$(echo $result_string | xargs)
    echo "$result_string"
}

# Getting count of success tests
# Input data: status_array
function fun_get_success {
    local count_success=0
    for i in "${status_array[@]}"; do
        if [ "$i" = true ]; then
            # count_success=$((count_success + 1))
            ((count_success++))
        fi
    done
    echo $count_success
}

function fun_get_sum_duration {
    local sum_duration=0
    for d in "${duration_array[@]}"; do
        local num=${d/ms*/}
        sum_duration=$(($sum_duration + $num))
    done
    echo "${sum_duration}ms"
}

#######################################################
# Creating the json string

# The node "testName"
testName=$(fun_get_testName)
JSON_STRING=$(jq -n --arg testName "$testName" '$ARGS.named')

# The node "testName"
COUNT_TESTS=$(fun_get_count_tests)
START_INDEX=3
CURRENT_INDEX=1
# Scanning tests.
while read -r string_test; do
    test_status=$(fun_get_test_status)
    status_array[$CURRENT_INDEX]=$test_status
    duration=$(fun_get_duration)
    duration_array[$CURRENT_INDEX]=$duration
    name=$(fun_get_name_of_test)
    JSON_STRING=$(jq --arg name "$name" \
                     --arg status $test_status \
                     --arg duration "$duration" \
                     '.tests += [{"name": $name, "status": $status | test("true"), "duration": $duration }]' \
                     <<<$JSON_STRING)
    ((CURRENT_INDEX++))
done < <(tail -n +${START_INDEX} $inputfile | head -n $COUNT_TESTS)

# The node "summary"
success=$(fun_get_success)
failed=$(($COUNT_TESTS - $success))
rating=$(echo "scale=6; (100 / $COUNT_TESTS) * $success" | bc)
rating=$(echo "scale=2; ($rating+0.005)/1" | bc)
duration=$(fun_get_sum_duration)

JSON_STRING=$(jq --arg success "$success" \
                 --arg failed "$failed" \
                 --arg rating "$rating" \
                 --arg duration "$duration" \
                 '.summary += { "success": $success | tonumber, "failed": $failed | tonumber, "rating": $rating | tonumber, "duration": $duration }' \
                  <<<$JSON_STRING)

#######################################################
# Saving to file
echo $JSON_STRING >$jsonfile
