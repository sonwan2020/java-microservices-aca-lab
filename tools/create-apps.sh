#!/usr/bin/env bash

DIR=/tmp

INGRESS=internal
PROFILE=mysql

create_app() {
    APP_NAME=$1

    echo "Start creating app $APP_NAME ..."

    cp -f ../tools/Dockerfile spring-petclinic-$APP_NAME/Dockerfile

    az containerapp create \
        --name $APP_NAME \
        --environment $ACA_ENVIRONMENT \
        --resource-group $RESOURCE_GROUP \
        --source ./spring-petclinic-$APP_NAME \
        --registry-server $MYACR.azurecr.io \
        --registry-identity $APPS_IDENTITY_ID \
        --ingress $INGRESS \
        --target-port 8080 \
        --min-replicas 1 \
        --env-vars SQL_SERVER=$MYSQL_SERVER_NAME SQL_USER=$MYSQL_ADMIN_USERNAME SQL_PASSWORD=secretref:sql-password SPRING_PROFILES_ACTIVE=$PROFILE \
        --secrets "sql-password=$MYSQL_ADMIN_PASSWORD" \
        --bind $JAVA_CONFIG_COMP_NAME $JAVA_EUREKA_COMP_NAME \
        --runtime java \
        > $DIR/$APP_NAME.create.log 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Create app $APP_NAME failed, check $DIR/$APP_NAME.create.log for more details"
        return 1
    fi

    echo "Create app $APP_NAME succeed"
    return 0
}

CHECK_FAIL=$DIR/aca-lab.$$

for name in customers-service vets-service visits-service; do
    create_app $name || touch $CHECK_FAIL &
done

wait < <(jobs -p)

if [[ -f $CHECK_FAIL ]]; then
    echo "Error happens on create apps, please check the logs for more details"
    exit 1
else
    echo "Create succeed"
    exit 0
fi

