pipeline {
    agent any
    stages {
        stage('Create Makefile') {
            steps {
                sh 'perl Makefile.PL'
            }
        }
        stage('build') {
            steps {
                sh 'perl -V'
            }
        }
    }
}
