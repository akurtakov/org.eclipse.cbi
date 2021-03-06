def latest_maven_release_gav(groupId, artifactId) {
  return sh(
    script: """
      _groupId=${groupId}
      latest_maven_release="\$(curl -sSL "https://repo1.maven.org/maven2/\${_groupId//\\.//}/${artifactId}/maven-metadata.xml" | xml sel -t -v "metadata/versioning/release")"
      echo "${groupId}:${artifactId}:\${latest_maven_release}"
    """,
    returnStdout: true
  ).trim()
}

pipeline {
  agent {
    kubernetes {
      label 'cbi-agent'
      defaultContainer 'cbi'
      yamlFile 'agentPod.yml'
    }
  }

  parameters { 
    string(name: 'RELEASE_VERSION', defaultValue: '', description: 'The version to be released e.g., 1.3.1') 
    string(name: 'NEXT_DEVELOPMENT_VERSION', defaultValue: '', description: 'The next version to be used e.g., 1.3.1-SNAPSHOT') 
    booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Whether the release steps should actually push changes to git and maven repositories, or not.')
  }

  environment {
    POM='pom.xml'
    MAVEN_OPTS='-Xmx1024m -Xms256m -XshowSettings:vm -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn'
    MAVEN_CONFIG = '-B -C -U -e'
    VERSIONS_MAVEN_PLUGIN = latest_maven_release_gav('org.codehaus.mojo', 'versions-maven-plugin')
    MAVEN_DEPENDENCY_PLUGIN = latest_maven_release_gav('org.apache.maven.plugins', 'maven-dependency-plugin')
    ARTIFACT_ID = sh(
      script: "xml sel -N mvn=\"http://maven.apache.org/POM/4.0.0\" -t -v  \"/mvn:project/mvn:artifactId\" \"${env.POM}\"",
      returnStdout: true
    )
    GROUP_ID = sh(
      script: "xml sel -N mvn=\"http://maven.apache.org/POM/4.0.0\" -t -v  \"(/mvn:project/mvn:groupId|/mvn:project/mvn:parent/mvn:groupId)[last()]\" \"${env.POM}\"",
      returnStdout: true
    )
  }

  tools {
    maven 'apache-maven-latest'
    jdk 'adoptopenjdk-openj9-latest-lts'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()
  }

  stages {
    stage('Prepare release') {
      when { 
        expression {
          params.RELEASE_VERSION != '' && params.NEXT_DEVELOPMENT_VERSION != ''
        }
      }
      steps {
        sh '''
          # set the version the the to-be released version and commit all changes made to the pom
          if [ "${DRY_RUN}" = true ]; then
            >&2 echo "DRY RUN: ${WORKSPACE}/mvnw \"${VERSIONS_MAVEN_PLUGIN}:set\" -DnewVersion=\"${RELEASE_VERSION}\" -DgenerateBackupPoms=false -f \"${POM}\""
            >&2 echo "DRY RUN: git config --global user.email \"cbi-bot@eclipse.org\""
            >&2 echo "DRY RUN: git config --global user.name \"CBI Bot\""
            >&2 echo "DRY RUN: git add --all"
            >&2 echo "DRY RUN: git commit -m \"Prepare release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}\""
            >&2 echo "DRY RUN: git tag \"${GROUP_ID}_${ARTIFACT_ID}_${RELEASE_VERSION}\" -m \"Release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}\""
          else
            "${WORKSPACE}/mvnw" "${VERSIONS_MAVEN_PLUGIN}:set" -DnewVersion="${RELEASE_VERSION}" -DgenerateBackupPoms=false -f "${POM}"
            git config --global user.email "cbi-bot@eclipse.org"
            git config --global user.name "CBI Bot"
            git add --all
            git commit -m "Prepare release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}"
            git tag "${GROUP_ID}_${ARTIFACT_ID}_${RELEASE_VERSION}" -m "Release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}"
            
            # quick check that we don't depend on SNAPSHOT anymore
            if "${WORKSPACE}/mvnw" "${MAVEN_DEPENDENCY_PLUGIN}:list" -f "${POM}" | grep SNAPSHOT; then
              >&2 echo "ERROR: At least one dependency to a 'SNAPSHOT' version has been found from '${POM}'"
              >&2 echo "ERROR: It is forbidden for releasing"
              exit 1
            fi

            if grep SNAPSHOT "${POM}"; then
              >&2 echo "ERROR: At least one 'SNAPSHOT' string has been found in '${POM}'"
              >&2 echo "ERROR: It is forbidden for releasing"
              exit 1
            fi
          fi
        '''
      }
    }

    stage('Display plugin/dependency updates') {
      steps {
        sh '''
          "${WORKSPACE}/mvnw" "${VERSIONS_MAVEN_PLUGIN}:display-plugin-updates" -f "${POM}"
          "${WORKSPACE}/mvnw" "${VERSIONS_MAVEN_PLUGIN}:display-dependency-updates" -f "${POM}"
        '''
      }
    }

    stage('Build') {
      steps {
        sh '"${WORKSPACE}/mvnw" clean verify -f "${POM}"'
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          if [ "${DRY_RUN}" = true ] && [ "${RELEASE_VERSION}" != "" ] && [ "${NEXT_DEVELOPMENT_VERSION}" != "" ]; then
            >&2 echo "DRY RUN: ${WORKSPACE}/mvnw deploy -f \"${POM}\""
          else
            "${WORKSPACE}/mvnw" deploy -f "${POM}"
          fi
        '''
      }
    }

    stage('Tag and push repo') {
      when { 
        expression {
          params.RELEASE_VERSION != '' && params.NEXT_DEVELOPMENT_VERSION != ''
        }
      }
      steps {
        sshagent(['git.eclipse.org-bot-ssh']) {
          sh '''
            if [ "${DRY_RUN}" = true ]; then
              >&2 echo "DRY RUN: git push origin \"${GROUP_ID}_${ARTIFACT_ID}_${RELEASE_VERSION}\""
              >&2 echo "DRY RUN: git push origin \"${GIT_BRANCH}\""
            else 
              git push origin "${GROUP_ID}_${ARTIFACT_ID}_${RELEASE_VERSION}"
              git push origin HEAD:"${GIT_BRANCH}"
            fi
          '''
        }
      }
    }

    stage('Prepare next development cycle') {
      when { 
        expression {
          params.RELEASE_VERSION != '' && params.NEXT_DEVELOPMENT_VERSION != ''
        }
      }
      steps {
        sshagent(['git.eclipse.org-bot-ssh']) {
          sh '''
            # clean and prepare for next iteration
            git clean -q -x -d -ff
            git checkout -q -f "${GIT_BRANCH}"
            git reset -q --hard "origin/${GIT_BRANCH}"

            "${WORKSPACE}/mvnw" "${VERSIONS_MAVEN_PLUGIN}:set" -DnewVersion="${NEXT_DEVELOPMENT_VERSION}" -DgenerateBackupPoms=false -f "${POM}"
            if [ "${DRY_RUN}" = true ]; then
              >&2 echo "DRY RUN: git add --all"
              >&2 echo "DRY RUN: git commit -m \"Prepare for next development iteration ${GROUP_ID}:${ARTIFACT_ID}:${NEXT_DEVELOPMENT_VERSION}\""
              >&2 echo "DRY RUN: git push origin \"${GIT_BRANCH}\""
            else
              # commit next iteration changes
              git add --all
              git commit -m "Prepare for next development iteration (${GROUP_ID}:${ARTIFACT_ID}:${NEXT_DEVELOPMENT_VERSION})"
              git push origin "${GIT_BRANCH}"
            fi
          '''
        }
      }
    }
  }
}
