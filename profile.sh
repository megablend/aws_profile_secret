#!/usr/bin/env sh
set -e

UPDATE_SECRET_VALUE_OPTION="update-secret-value"
UPDATE_SECRET_CERT_OPTION="update-secret-cert"
NEW_SECRET_VALUE_OPTION="new-secret"
DOWNLOAD_SECRET_VALUE_OPTION="download-secret"
SECRET_KEY_OPTION="--secret-key"
SECRET_VALUE_OPTION="--secret-value"
SECRET_ID_OPTION="--secret-id"
SECRET_CERT_FILE_PATH_OPTION="--cert-file"
NEW_SECRET_JSON_OPTION="--json-file"
EXTENSION_OPTION="--ext"
AWS_PROFILE="--profile"

upload_secret_details () {
    tmp_json_file="tmp.json"
    retrieved_existing_values=$(aws secretsmanager get-secret-value --secret-id $1  --profile $2 --version-stage AWSCURRENT | jq '.SecretString')
    trimmed_secrets_value=$retrieved_existing_values

    if [[ ${retrieved_existing_values: -1} != '"' ]]; then
        trimmed_secrets_value=${retrieved_existing_values%?}
    fi

    last_characters_of_cli_uploaded_values="\\n\"" # cli updated values append newlines to the provisioned secrets
    if [[ ${retrieved_existing_values: -3} == $last_characters_of_cli_uploaded_values ]]; then
        trimmed_secrets_value=${retrieved_existing_values%???}
    fi
    printf "%s" "$trimmed_secrets_value" | sed 's#"{\\#{#g' | sed 's#\\"#"#g' | sed 's#\\\\n#\\n#g' | sed 's#{n#{#g' | sed 's#",\\n#",#g' | sed 's#"\\n}#"}#g' | sed 's#}\\n#}#g' | sed 's#"{#{#g' | sed 's#}"#}#g' | sed 's#\\\\"#\\"#g' | jq ".\"$3\" = \"$4\"" > $tmp_json_file
    aws secretsmanager put-secret-value --secret-id $1 --secret-string file://$tmp_json_file --profile $2 --version-stages AWSCURRENT
    rm $tmp_json_file
}

download_secret_details () {
    download_file=$(printf "%s" "$3" | sed -E 's/[^[:alnum:][:space:]]+/_/g')
    download_file=$(printf "%s" "$download_file.$4")
    retrieved_existing_values=$(aws secretsmanager get-secret-value --secret-id $1  --profile $2 --version-stage AWSCURRENT | jq '.SecretString')
    trimmed_secrets_value=$retrieved_existing_values

    if [[ ${retrieved_existing_values: -1} != '"' ]]; then
        trimmed_secrets_value=${retrieved_existing_values%?}
    fi

    last_characters_of_cli_uploaded_values="\\n\"" # cli updated values append newlines to the provisioned secrets
    if [[ ${retrieved_existing_values: -3} == $last_characters_of_cli_uploaded_values ]]; then
        trimmed_secrets_value=${retrieved_existing_values%???}
    fi

    downloaded_content=$(printf "%s" "$trimmed_secrets_value" | sed 's#"{\\#{#g' | sed 's#\\"#"#g' | sed 's#\\\\n#\\n#g' | sed 's#{n#{#g' | sed 's#",\\n#",#g' | sed 's#"\\n}#"}#g' | sed 's#}\\n#}#g' | sed 's#"{#{#g' | sed 's#}"#}#g' | sed 's#\\\\"#\\"#g' | jq ".\"$3\"" | cut -c 1-)
    downloaded_content=${downloaded_content#?}
    downloaded_content=${downloaded_content%?}

    # restore escaped quote if any
    if [[ $downloaded_content == *"\\\""* ]]; then
        downloaded_content=$(printf "%s" "$downloaded_content" | sed 's#\\"#"#g')
    fi
    echo ${downloaded_content} > $download_file
    echo "File successfully downloaded as $download_file. Update the new values and re-uploaded using the $UPDATE_SECRET_CERT_OPTION command"
}

upload_new_secret () {
    aws secretsmanager put-secret-value --secret-id $1 --secret-string file://$2 --profile $3 --version-stages AWSCURRENT
}

validate_jq_existence () {
    # check if jq exists, else grab it using homebrew (assuming everyone is using this)
    if ! jq --version &>/dev/null; then
        echo "You don't have jq installed, required for JSON manipulation. Installing one on your behalf..."
        brew install jq # assuming you use brew for your software management
    fi
}


case $1 in
    # Handle the upload of certificates to SSM
    $UPDATE_SECRET_CERT_OPTION)
        if [[ "$#" -ne 9 ]] || [[ $2 != $SECRET_ID_OPTION ]] || [[ $4 != $SECRET_KEY_OPTION ]] || [[ $6 != $SECRET_CERT_FILE_PATH_OPTION ]] || [[ $8 != $AWS_PROFILE ]]; then
        printf "\n\n"
cat <<- EOF
  Invalid parameters provided for uploading cert details to AWS SSM. See example command below:
  usage: ./aws_secret_upload.sh <command> [<parameters>...]
  example: ./aws_secret_upload.sh update-secret-cert --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_FOR_CERT> --cert-file <ABSOLUTE_PATH_OF_CERT> --profile <YOUR_AWS_PROFILE>
EOF
        else
            # read a file and convert to one line
            cert_file=$7
            if test -f $cert_file; then
                validate_jq_existence

                # Note: using perl to avoid trailing new line, most linux based OS has `perl` pre-installed
                file_content=$(perl -pe 's/\n/\\n/' < ${cert_file})
                updated_file_content=$file_content

                # remove trailing newline from the file content if any
                last_two_characters=$(printf "%s" "${file_content: -2}" | sed 's#\\n##g')
                if [[ $last_two_characters == '' ]]; then
                    updated_file_content=${file_content%??}
                fi

                # escape quotes, breaks jq since is a reserved JSON character
                if [[ $updated_file_content == *"\""* ]]; then
                    updated_file_content=$(printf "%s" "$updated_file_content" | sed 's#"#\\"#g')
                fi
                upload_secret_details $3 $9 $5 "$updated_file_content"
            else
                echo "Invalid certificate file path <${cert_file}> provided for ${SECRET_CERT_FILE_PATH_OPTION}, please ensure that the file exists."
                exit 1
            fi
        fi
        ;;
    $DOWNLOAD_SECRET_VALUE_OPTION)
        if [[ "$#" -ne 9 ]] || [[ $2 != $SECRET_ID_OPTION ]] || [[ $4 != $SECRET_KEY_OPTION ]] || [[ $6 != $EXTENSION_OPTION ]] || [[ $8 != $AWS_PROFILE ]]; then
        printf "\n\n"
cat <<- EOF
  Invalid parameters provided for downloading details to AWS SSM. See example command below:
  usage: ./aws_secret_upload.sh <command> [<parameters>...]
  example: ./aws_secret_upload.sh download-secret --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_BE_DOWNLOADED_AS_FILE> --ext <THE_FILE_EXTENSION> --profile <YOUR_AWS_PROFILE>
EOF
        else
            validate_jq_existence
            download_secret_details $3 $9 $5 $7
        fi
        ;;
    $UPDATE_SECRET_VALUE_OPTION) # Limitation: can only update one key [have fun making it deal with multiple keys :)]
        if [[ "$#" -ne 9 ]] || [[ $2 != $SECRET_ID_OPTION ]] || [[ $4 != $SECRET_KEY_OPTION ]] || [[ $6 != $SECRET_VALUE_OPTION ]] || [[ $8 != $AWS_PROFILE ]]; then
        printf "\n\n"
cat <<- EOF
  Invalid parameters provided for updating secret key value to AWS SSM. See example command below:
  usage: ./aws_secret_upload.sh <command> [<parameters>...]
  example: ./aws_secret_upload.sh update-secret-value --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_ADD_OR_UPDATE> --secret-value <THE_NEW_VALUE> --profile <YOUR_AWS_PROFILE>
EOF
        else
            validate_jq_existence
            upload_secret_details $3 $9 $5 $7
        fi
        ;;
    $NEW_SECRET_VALUE_OPTION)
        if [[ "$#" -ne 7 ]] || [[ $2 != $SECRET_ID_OPTION ]] || [[ $4 != $NEW_SECRET_JSON_OPTION ]] || [[ $6 != $AWS_PROFILE ]]; then
        printf "\n\n"
cat <<- EOF
  Invalid parameters provided for creating new secret values. See example command below:
  usage: ./aws_secret_upload.sh <command> [<parameters>...]
  example: ./aws_secret_upload.sh new-secret --secret-id <YOUR_AWS_SECRET_ID> --json-file <THE_JSON_FILE_WITH_THE_KEY_VALUE_PAIR> --profile <YOUR_AWS_PROFILE>
EOF
        else
            if test -f $5; then
                upload_new_secret $3 $5 $7
            else
                echo "Invalid JSON file path <${5}> provided for ${NEW_SECRET_VALUE_OPTION}, please ensure that the file exists."
                exit 1
            fi
        fi
        ;;
    *)
    nl=$'\n'
    printf "\n"
cat <<- EOF
  Invalid command provided, see examples below:
  usage: ./aws_secret_upload.sh <command> [<parameters>...] $nl
  Upload certificate details
  example: ./aws_secret_upload.sh update-secret-cert --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_FOR_CERT> --cert-file <ABSOLUTE_PATH_OF_CERT> --profile <YOUR_AWS_PROFILE>$nl
  Update secret key value
  example: ./aws_secret_upload.sh update-secret-value --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_ADD_OR_UPDATE> --secret-value <THE_NEW_VALUE> --profile <YOUR_AWS_PROFILE>$nl
  New secret key value
  example: ./aws_secret_upload.sh new-secret --secret-id <YOUR_AWS_SECRET_ID> --json-file <THE_JSON_FILE_WITH_THE_KEY_VALUE_PAIR> --profile <YOUR_AWS_PROFILE>$nl
  Download secret key value as file
  example: ./aws_secret_upload.sh download-secret --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_BE_DOWNLOADED_AS_FILE> --ext <THE_FILE_EXTENSION> --profile <YOUR_AWS_PROFILE>
EOF
        ;;
esac