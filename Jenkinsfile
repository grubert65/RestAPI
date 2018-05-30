pipeline {
    agent { docker { image 'perl:threaded' } }
    stages {
        stage('build') {
            steps {
                sh 'perl -V'
            }
        }
    }
}
