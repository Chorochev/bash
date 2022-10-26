#!/bin/bash

filepath=$1
newfilepath="accounts_new.csv"
######################################################
# Creating an array of headers
first_line=$(head -n 1 $filepath)
headers=(${first_line//,/ })
declare -A hash_headers
for ((i = 0; i < ${#headers[@]}; i++)); do
    hash_headers[${headers[$i]}]=$i
done
######################################################
# Getting data
# Creating a temporary file.
temp_accounts=$(mktemp)
# Save to file each cell on new line
while read line; do
    echo $line | awk -vFPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '{for (i=1; i<=NF; i++) { print $i }}' >>$temp_accounts
done <$filepath

columns=${#headers[@]}
skip_lines=$((columns + 1))
current_column=0
rows=0
line_index=0
declare -a names
declare -a locations
declare -a emails
declare -A check_emails
######################################################
# Getting locations and names
while read line; do
    if ((current_column == columns)); then
        current_column=0
        ((rows++))
    fi

    if ((${hash_headers[location_id]} == current_column)); then locations[$rows]=$line; fi
    if ((${hash_headers[name]} == current_column)); then names[$rows]=$line; fi

    ((current_column++))
    ((line_index++))
done < <(tail -n +$skip_lines $temp_accounts)

######################################################
# Updating data
count_row=${#names[@]}
for ((i = 0; i < $count_row; i++)); do
    # Formatting the name
    arr_name=(${names[$i]})
    for ((j = 0; j < ${#arr_name[@]}; j++)); do
        # The name may be double.
        # Converting a double name to an array.
        arr_double_name=(${arr_name[$j]//-/ })
        for ((y = 0; y < ${#arr_double_name[@]}; y++)); do
            # Doing lowercase all the letters.
            arr_double_name[$y]="${arr_double_name[$y],,}"
            # Doing uppercase the first letter.
            arr_double_name[$y]="${arr_double_name[$y]^}"
        done
        # Converting an array to a double name.
        arr_name[$j]=$(printf "%s-" "${arr_double_name[@]}" | cut -d "-" -f 1-${#arr_double_name[@]})
    done
    new_name=${arr_name[*]}
    names[$i]=$new_name

    # Creating the part of email
    firstletter=${arr_name[0]:0:1}
    surname=$arr_name[1]
    new_email="${firstletter}${arr_name[1]}"
    new_email="${new_email,,}"
    emails[$i]=$new_email
    ((check_emails[$new_email]++))
done

######################################################
# Creating emails
count_row=${#names[@]}
for ((i = 0; i < $count_row; i++)); do
    email=${emails[$i]}
    if ((check_emails[$email] > 1)); then
        new_email="${email}${locations[$i]}@abc.com"
    else
        new_email="$email@abc.com"
    fi
    emails[$i]=$new_email
done

######################################################
# Creating "accounts_new.csv"
echo $first_line >$newfilepath

echo "" >>$temp_accounts # it needs for next while

declare -A cur_row
current_column=0
rows=0
while read line; do
    if ((current_column == columns)); then
        # Adding a new row to "accounts_new.csv"
        id=${cur_row[id]}
        location_id=${cur_row[location_id]}
        name=${names[$rows]}
        title=${cur_row[title]}
        new_email=${emails[$rows]}
        department=${cur_row[department]}
        # Append a new row
        echo "$id,$location_id,$name,$title,$new_email,$department" >>$newfilepath

        current_column=0
        ((rows++))
    fi

    # Remembering columns
    if ((${hash_headers[id]} == current_column)); then cur_row[id]=$line; fi
    if ((${hash_headers[location_id]} == current_column)); then cur_row[location_id]=$line; fi
    if ((${hash_headers[title]} == current_column)); then cur_row[title]=$line; fi
    if ((${hash_headers[department]} == current_column)); then cur_row[department]=$line; fi

    ((current_column++))
done < <(tail -n +$skip_lines $temp_accounts)

# Deleting the temporary file
rm ${temp_accounts}
