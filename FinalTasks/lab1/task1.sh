#! /bin/bash
# Reading headers of CSV file.
first_line=$(head -n 1 $1)
# Removing commas.
headers=${first_line//,/ }
# Creating a temporary file.
temp_accounts=$(mktemp)
# An array of emails
declare -A email_array

# Reading all the file.
while IFS="," read -r $headers; do
    ######################################################
    # Formatting the name
    arr_name=($name)
    for ((i = 0; i < ${#arr_name[@]}; i++)); do
        # The name may be double.
        # Converting a double name to an array.
        arr_double_name=(${arr_name[$i]//-/ })
        for ((j = 0; j < ${#arr_double_name[@]}; j++)); do
            # Doing lowercase all the letters.
            arr_double_name[$j]="${arr_double_name[$j],,}"
            # Doing uppercase the first letter.
            arr_double_name[$j]="${arr_double_name[$j]^}"
        done
        # Converting an array to a double name.
        arr_name[$i]=$(printf "%s-" "${arr_double_name[@]}" | cut -d "-" -f 1-${#arr_double_name[@]})
    done
    new_name=${arr_name[*]}
    ######################################################
    # Creating the email
    firstletter=${arr_name[0]:0:1}
    surname=$arr_name[1]
    new_email="${firstletter}${arr_name[1]}"
    new_email="${new_email,,}"
    ((email_array[$new_email]++))
    # Append a new row
    echo "$id,$location_id,$new_name,$title,$new_email,$department" >>$temp_accounts
done < <(tail -n +2 $1)

# Creating "accounts_new.csv"
echo "$first_line" >accounts_new.csv
# Reading all the file.
while IFS="," read -r $headers; do
    if ((email_array[$email] > 1)); then
        new_email="${email}${location_id}@abc.com"
    else
        new_email="$email@abc.com"
    fi
    # Append a new row
    echo "$id,$location_id,$name,$title,$new_email,$department" >>accounts_new.csv
done <$temp_accounts

# Deleting the temporary file
rm ${temp_accounts}
