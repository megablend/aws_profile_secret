# profile_aws_secret
This script helps provision secret data file on AWS, create new secrets and update existing keys or add new ones using CLI

## Usage
Below are the various functionalities this script provides:

## Download secret key details as file
This allows you to modify existing configuration, makes changes to it locally and re-upload using the `upload-secret-data` command.
See command below:
```bash
  ./profile.sh download-secret --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_BE_DOWNLOADED_AS_FILE> --ext <THE_DESIRED_FILE_EXTENSION> --profile <YOUR_AWS_PROFILE>
```
Example:
```bash
  ./profile.sh download-secret --secret-id app_secret_id --secret-key some/secrets --ext rb --profile aws_profile
```

## Add/Update file details to a specific AWS secret key
See command below:
```bash
  ./profile.sh update-secret-data --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_FOR_FILE_DATA> --data-file <ABSOLUTE_PATH_OF_CERT> --profile <YOUR_AWS_PROFILE>
```
Example:
```bash
  ./profile.sh update-secret-data --secret-id app_secret_id --secret-key some/secrets --data-file /path/to/file --profile aws_profile
```

## Add/Update secret value of a key
See command below:
```bash
  ./profile.sh update-secret-value --secret-id <YOUR_AWS_SECRET_ID> --secret-key <THE_KEY_TO_ADD_OR_UPDATE> --secret-value <THE_NEW_VALUE> --profile <YOUR_AWS_PROFILE>
```
Example:
```bash
  ./profile.sh update-secret-value --secret-id app_secret_id --secret-key database_password --secret-value password --profile aws_profile
```

## Provision new secret values for a new service
See command below:
```bash
  ./profile.sh new-secret --secret-id <YOUR_AWS_SECRET_ID> --json-file <THE_JSON_FILE_WITH_THE_KEY_VALUE_PAIR> --profile <YOUR_AWS_PROFILE>
```
Example:
```bash
  ./profile.sh new-secret --secret-id app_secret_id --json-file /app/test.json --profile aws_profile
```