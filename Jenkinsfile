#!/usr/bin/env groovy
def propagateParamsToEnv() {
  for (param in params) {
    if (env."${param.key}" == null) {
      env."${param.key}" = param.value
    }
  }
}


properties([
  disableConcurrentBuilds(),
  parameters([
    string(name: 'TAG',
           defaultValue: '',
           description: 'Git tag to build'),
    string(name: 'GRAVITY_VERSION',
           defaultValue: '9.0.9',
           description: 'gravity/tele binaries version'),
    string(name: 'EXTRA_GRAVITY_OPTIONS',
           defaultValue: '',
           description: 'Gravity options to add when calling tele'),
    booleanParam(name: 'ADD_GRAVITY_VERSION',
                 defaultValue: false,
                 description: 'Appends "-${GRAVITY_VERSION}" to the tag to be published'),
    booleanParam(name: 'PUBLISH_APP_PACKAGE',
                 defaultValue: false,
                 description: 'Import application to S3 bucket'),
    booleanParam(name: 'BUILD_GRAVITY_APP',
                 defaultValue: true,
                 description: 'Generate a Gravity App tarball'),
  ]),
])

node {
  skipDefaultCheckout()
  workspace {
    stage('checkout') {
      print 'Running stage Checkout source'

      def branches
      if (params.TAG == '') { // No tag specified
        branches = scm.branches
      } else {
        branches = [[name: "refs/tags/${params.TAG}"]]
      }

      checkout([
        $class: 'GitSCM',
        branches: branches,
        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
        extensions: [[$class: 'CloneOption', noTags: false, shallow: false]],
        submoduleCfg: [],
        userRemoteConfigs: scm.userRemoteConfigs,
      ])
    }
    stage('params') {
      echo "${params}"
      propagateParamsToEnv()
    }
    stage('clean') {
      sh "make clean"
    }

    APP_VERSION = sh(script: 'make what-version', returnStdout: true).trim()
    APP_VERSION = params.ADD_GRAVITY_VERSION ? "${APP_VERSION}-${GRAVITY_VERSION}" : APP_VERSION
    STATEDIR = "${pwd()}/state/${APP_VERSION}"
    BINARIES_DIR = "${pwd()}/bin"
    MAKE_ENV = [
      "PATH+GRAVITY=${BINARIES_DIR}",
      "VERSION=${APP_VERSION}"
    ]

    stage('download gravity/tele binaries for login') {
      withCredentials([
        [
          $class          : 'UsernamePasswordMultiBinding',
          credentialsId   : 'aws-onprem',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY',
          usernameVariable: 'AWS_ACCESS_KEY_ID'
        ]
      ]) {
        withEnv(MAKE_ENV + ["BINARIES_DIR=${BINARIES_DIR}"]) {
          sh 'make download-binaries'
        }
      }
    }

    stage('export') {
      if (params.BUILD_GRAVITY_APP) {
        withCredentials([
            [
              $class          : 'UsernamePasswordMultiBinding',
              credentialsId   : 'harbor-docker-registry',
              passwordVariable: 'HARBOR_PASS',
              usernameVariable: 'HARBOR_USER'
            ]
        ]) {
          withEnv(MAKE_ENV) {
            sh """
              rm -rf ${STATEDIR} && mkdir -p ${STATEDIR}
              make export"""
            archiveArtifacts "build/application.tar"
          }
        }
      } else {
        echo 'skipped application export'
      }
    }

    stage('upload application image to S3') {
      if (params.PUBLISH_APP_PACKAGE && params.BUILD_GRAVITY_APP) {
        withCredentials([
          [
            $class          : 'UsernamePasswordMultiBinding',
            credentialsId   : 'aws-onprem',
            passwordVariable: 'AWS_SECRET_ACCESS_KEY',
            usernameVariable: 'AWS_ACCESS_KEY_ID'
          ]
        ]) {
          withEnv(MAKE_ENV + ["BINARIES_DIR=${BINARIES_DIR}"]) {
            sh 'make upload-application'
          }
        }
      }
    }
  }
}

void workspace(Closure body) {
  timestamps {
    ws("${pwd()}-${BUILD_ID}") {
      body()
    }
  }
}
