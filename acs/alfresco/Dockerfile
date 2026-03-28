# syntax=docker/dockerfile:1.7

# Global ARGs must be declared before any FROM so they can be used in FROM instructions.
ARG ALFRESCO_TAG

############################################
# Stage 1: Build content-lake-repo-model from source
############################################
FROM maven:3.9.9-eclipse-temurin-21-alpine AS model-build

WORKDIR /src

COPY --from=content_lake_app . .

RUN --mount=type=cache,target=/root/.m2 \
    mvn -q -DskipTests -pl common/content-lake-repo-model -am package

############################################
# Stage 2: Alfresco with the model JAR
############################################
FROM alfresco/alfresco-content-repository-community:${ALFRESCO_TAG}

ARG TOMCAT_DIR=/usr/local/tomcat

USER root

COPY --from=model-build /src/common/content-lake-repo-model/target/content-lake-repo-model-*.jar \
  ${TOMCAT_DIR}/webapps/alfresco/WEB-INF/lib/

USER alfresco
