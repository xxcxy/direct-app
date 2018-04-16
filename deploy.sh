#!/bin/bash
ENV=$1
APPVER=$2

if [ -z $APPVER ] || [ -z $ENV ];
then
 echo "The script need to be executed with version ex:deploy.sh ENV 123"
 exit 1
fi

BUILD_VARIABLE_FILE_NAME="./buildvar.conf"
source $BUILD_VARIABLE_FILE_NAME

if [ "$DEPLOY" = "1" ] ;
then
    echo "build variables are imported. Proceeding deployment"
else
    echo "User skipped deployment by updating the DEPLOY variable other than 1"
    exit 1
fi

SECRET_FILE_NAME="${APPNAME}-buildsecvar.conf"
cp ./../buildscript/${APPNAME}/${SECRET_FILE_NAME}.enc .
if [ -f "$SECRET_FILE_NAME" ];
then
   rm -rf $SECRET_FILE_NAME
fi
openssl enc -aes-256-cbc -d -in $SECRET_FILE_NAME.enc -out $SECRET_FILE_NAME -k $SECPASSWD
source $SECRET_FILE_NAME

AWS_REGION=$(eval "echo \$${ENV}_AWS_REGION")
AWS_ACCESS_KEY_ID=$(eval "echo \$${ENV}_AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(eval "echo \$${ENV}_AWS_SECRET_ACCESS_KEY")
AWS_ACCOUNT_ID=$(eval "echo \$${ENV}_AWS_ACCOUNT_ID")
AWS_CD_APPNAME=$(eval "echo \$${ENV}_AWS_CD_APPNAME")
AWS_CD_DG_NAME=$(eval "echo \$${ENV}_AWS_CD_DG_NAME")
AWS_CD_DG_CONFIGURATION=$(eval "echo \$${ENV}_AWS_CD_DG_CONFIGURATION")
AWS_S3_BUCKET=$(eval "echo \$${ENV}_AWS_S3_BUCKET")
AWS_S3_KEY_LOCATION=$(eval "echo \$${ENV}_AWS_S3_KEY_LOCATION")

AWS_CD_PACKAGE_NAME="${APPNAME}-${PACKAGETYPE}-${APPVER}.zip"
if [ "$AWS_S3_KEY_LOCATION" = "" ] ;
then
    AWS_S3_KEY="${AWS_CD_PACKAGE_NAME}"
else
    AWS_S3_KEY="$AWS_S3_KEY_LOCATION/${AWS_CD_PACKAGE_NAME}"
fi

#log Function - Used to provide information of execution information with date and time
log()
{
   echo "`date +'%D %T'` : $1"
}

#track_error function validates whether the application execute without any error
track_error()
{
   if [ $1 != "0" ]; then
        log "$2 exited with error code $1"
        log "completed execution IN ERROR at `date`"
        exit $1
   fi

}

#Function for aws login
configure_aws_cli() {
	aws --version
	aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
	aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
	aws configure set default.region $AWS_REGION
	aws configure set default.output json
	log "Configured AWS CLI."
}


#uploading to S3 bucket
upload_cd_pakcage()
{
    S3_URL=""
	if [ "$AWS_S3_KEY_LOCATION" = "" ] ;
	then
		S3_URL="s3://${AWS_S3_BUCKET}/"
	else
		S3_URL="s3://${AWS_S3_BUCKET}/${AWS_S3_KEY_LOCATION}/"
	fi
	aws s3 cp ${AWS_CD_PACKAGE_NAME} $S3_URL
	track_error $? "Package S3 deployment"
	log "CD Package uploaded successfully to S3 bucket $S3_URL"
}
#register the revision in Code deploy
update_cd_app_revision()
{
	aws deploy register-application-revision --application-name "${AWS_CD_APPNAME}" --s3-location bucket=${AWS_S3_BUCKET},bundleType=zip,key=${AWS_S3_KEY}
	track_error $? "CD applicaton register"
	log "CD application register completed successfully"
}
#Invoke the code deploy
cd_deploy()
{
	$DEPLOYID=`aws deploy create-deployment --application-name "${AWS_CD_APPNAME}" --deployment-config-name ${AWS_CD_DG_CONFIGURATION} --deployment-group-name ${AWS_CD_DG_NAME} --s3-location bucket=code-deploy-hello,bundleType=zip,key=${AWS_S3_KEY}`
	track_error $? "CD applicaton register"
	log "CD application register completed successfully. Please find the $DEPLOYID"
}
#Checing the status
cd_deploy_status()
{
	echo "check statusget info aws deploy get-deployment --deployment-id d-USUAELQEX"
	
}
configure_aws_cli
upload_cd_pakcage
update_cd_app_revision
cd_deploy
#cd_deploy_status


