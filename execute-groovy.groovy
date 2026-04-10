import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.*
import org.jenkinsci.plugins.workflow.cps.*

def instance = Jenkins.getInstance()

def jobName = "monitoring-app-deploy"

def job = instance.getItem(jobName)

if (job == null) {

    job = instance.createProject(WorkflowJob, jobName)

    def pipelineScript = """
pipeline {
    agent any

    stages {
        stage('Clone Repo') {
            steps {
                git branch: 'main', url: 'https://github.com/lavatech321/Monitoring_Stack_App.git'
            }
        }

        stage('Run Docker Compose') {
            steps {
                dir('app') {
                    sh 'docker compose up -d'
                }
            }
        }
    }
}
"""

    job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
    job.save()
}

instance.save()

// 🔥 TRIGGER BUILD AUTOMATICALLY
job.scheduleBuild2(0)
