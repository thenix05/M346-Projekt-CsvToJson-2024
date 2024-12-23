#!/bin/bash

CSV_PATH=$1
CSV_BUCKET="upload-bucket-csv-lmt-gbs"
JSON_BUCKET="download-bucket-json-lmt-gbs"
LAMBDA_NAME="CsvToJsonLambda"
REGION="us-east-1"

#Erstellt oder Leer die S3-Buckets
createBucket(){
  BUCKET=$1
  echo "Bucket $BUCKET wird erstellt..."
  if ! aws s3 mb s3://$BUCKET --region $REGION >/dev/null 2>&1; then      
    echo "Bucket $BUCKET konnte nicht erstellt werden."
    exit 1;
  fi
  echo -e "Bucket $BUCKET wurde erfolgreich erstellt.\n"
}

#Prüft, ob die Lambda funktion bereits existiert
check_lambda_exists() {
  if aws lambda get-function --function-name $LAMBDA_NAME --region $REGION >/dev/null 2>&1; then
    echo -e "Lambda-Funktion $LAMBDA_NAME existiert bereits.\nInitialisierung wird übersprungen."
    return 0
  else
    echo -e "Lambda-Funktion $LAMBDA_NAME existiert nicht.\nInitialisierung wird durchgeführt..."
    return 1
  fi
}

#Diese Methode erstellt den Trigger
addTrigger(){
  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region $REGION)
  if [ $? -ne 0 ]; then
    echo "Fehler beim Abrufen der Account-ID."
    exit 1
  fi

  echo "CSV-Bucket Trigger wird erstellt..."
  if ! aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id "$(uuidgen)" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$CSV_BUCKET \
    --source-account $ACCOUNT_ID \
    --region $REGION; then
    echo "CSV-Bucket Trigger konnte nicht erstellt werden."; 
    exit 1;
    fi
  echo -e "CSV-Bucket Trigger wurde erfolgreich erstellt.\n"

}

#Diese Methode holt den Lambda Arn
getLambdaArn(){
  echo "Lambda Arn wird geholt..."
  LAMBDA_ARN=$(
    aws lambda get-function \
        --function-name $LAMBDA_NAME \
        --region $REGION \
        --query 'Configuration.FunctionArn' \
        --output text
  ) 

    if [ $? -ne 0 ] || [ -z "$LAMBDA_ARN" ]; then
    echo "Lambda Arn konnte nicht geholt werden."
    exit 1
  fi

  echo -e "Lambda Arn wurde erfolgreich geholt.\n"
}

#Diese Methode setzt den Trigger 
putBucketNotificationConfiguration() {
  echo "Bucket Notification Configuration wird gesetzt..."
  echo $LAMBDA_ARN
 if ! aws s3api put-bucket-notification-configuration \
    --bucket $CSV_BUCKET \
    --notification-configuration '{
        "LambdaFunctionConfigurations":[{
            "LambdaFunctionArn":"'"$LAMBDA_ARN"'",
            "Events":["s3:ObjectCreated:*"]
        }]
    }' --region $REGION; then
      echo "Bucket Notification Configuration konnte nicht gesetzt werden."
      exit 1;
    fi
  echo -e "Bucket Notification Configuration wurde erfolgreich gesetzt.\n"
}

#Prüft ob der CSV-Pfad vorhanden ist
if [ ! -f $CSV_PATH ]; then
  echo "Die angegebene CSV-Datei existiert nicht: $CSV_PATH"
  exit 1
fi

#Skippt die Initialiesierung wenn Lambda bereits existiert.
if ! check_lambda_exists; then
  echo -e "Komponenten werden initialisiert...\n"
  createBucket $CSV_BUCKET
  createBucket $JSON_BUCKET
  cd $LAMBDA_NAME/src/$LAMBDA_NAME
  dotnet lambda deploy-function $LAMBDA_NAME --function-role LabRole 
  echo $CSV_PATH
  dotnet lambda invoke-function $LAMBDA_NAME
  cd ../../../
  addTrigger
  getLambdaArn
  putBucketNotificationConfiguration
  echo -e "Komponenten wurden erfolgreich initialisiert.\n"
fi


#CSV-Datei wird hochgeladen
echo "CSV wird hochgeladen..."
aws s3 cp $CSV_PATH s3://$CSV_BUCKET/$(basename $CSV_PATH)
echo -e "CSV wurde erfolgreich hochgeladen.\n"

JSON_KEY=$(basename $CSV_PATH .csv).json
JSON_LOCAL_PATH=$(dirname $CSV_PATH)/$JSON_KEY

#Es wird auf die Json-Datei im Bucket gewartet
while true; do
  if aws s3 ls s3://$JSON_BUCKET/$JSON_KEY; then
    echo "JSON-Datei ist verfügbar: s3://$JSON_BUCKET/$JSON_KEY"
    break
  else
    echo "Warte auf JSON-Datei im JsonBucket..."
    sleep 10 
  fi
done

#Json-Datei wird heruntergeladen
echo "Json-Datei wird heruntergeladen..."
aws s3 cp s3://$JSON_BUCKET/$JSON_KEY $JSON_LOCAL_PATH
echo "Json-Datei wurde erfolgreich heruntergeladen: $JSON_LOCAL_PATH"
