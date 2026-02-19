pipeline {
    agent any

    environment {
        CLIENT_ID        = 5edcfcf8-9dbd-4c1b-a602-a0887f677e2e
        CLIENT_SECRET    = _5S8Q~g5IB33yW~tq9lPokpO1pL~V-pHpMP-hbMr
        TENANT_ID        = 6fbff720-d89b-4675-b188-48491f24b460

        DEV_WORKSPACE_ID = "91c74549-7e98-4088-a9a0-0855c9c3b466"
        QA_WORKSPACE_ID  = "dd03f00e-302f-42c9-99d8-8bcb92687612"

        SEMANTIC_MODEL_ID = "5bd5e7ae-95ff-4251-8fd3-f6d14fa8439c"
        MODEL_FOLDER      = "Customer-A/Sales_Model_A.SemanticModel"

        QA_CONNECTION_ID = "ddf2b3a8-c6c4-4bf0-ac43-ee79fe113877"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'dev',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/Prathmesh2806/Fabric-Automation.git'
            }
        }

        stage('Get Token') {
            steps {
                script {
                    def tokenResponse = sh(script: """
                        curl -s -X POST https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token \
                        -d grant_type=client_credentials \
                        -d client_id=${CLIENT_ID} \
                        -d client_secret=${CLIENT_SECRET} \
                        -d scope=https://api.fabric.microsoft.com/.default
                    """, returnStdout: true)

                    env.TOKEN = readJSON(text: tokenResponse).access_token
                }
            }
        }

        stage('Prepare Model Payload') {
            steps {
                script {

                    def pbismBase64 = sh(script: "base64 -w 0 ${MODEL_FOLDER}/definition.pbism", returnStdout: true).trim()

                    def parts = [[path: "definition.pbism", payload: pbismBase64, payloadType: "InlineBase64"]]

                    def tmdlFiles = sh(script: "find ${MODEL_FOLDER}/definition -name '*.tmdl'", returnStdout: true).split()

                    tmdlFiles.each { filePath ->
                        def relativePath = filePath.substring(filePath.indexOf("definition/"))
                        def fileBase64 = sh(script: "base64 -w 0 ${filePath}", returnStdout: true).trim()
                        parts << [path: relativePath, payload: fileBase64, payloadType: "InlineBase64"]
                    }

                    writeJSON file: 'model_payload.json', json: [
                        displayName: "Sales_Model_A",
                        type: "SemanticModel",
                        definition: [parts: parts]
                    ]
                }
            }
        }

        stage('Deploy To QA Workspace') {
            steps {
                script {

                    def responseHeaders = sh(script: """
                        curl -i -s -X POST \
                        https://api.fabric.microsoft.com/v1/workspaces/${QA_WORKSPACE_ID}/items/${SEMANTIC_MODEL_ID}/updateDefinition \
                        -H 'Authorization: Bearer ${env.TOKEN}' \
                        -H 'Content-Type: application/json' \
                        -d @model_payload.json
                    """, returnStdout: true)

                    def opUrl = sh(script: "echo '${responseHeaders}' | grep -i 'location:' | awk '{print \$2}' | tr -d '\\r'", returnStdout: true).trim()

                    if (!opUrl) error "❌ QA Deployment did not start."

                    while (true) {
                        sleep 15
                        def statusRaw = sh(script: "curl -s -H 'Authorization: Bearer ${env.TOKEN}' ${opUrl}", returnStdout: true)
                        def statusJson = readJSON(text: statusRaw)

                        if (statusJson.status == "Succeeded") break
                        if (statusJson.status == "Failed") error "❌ QA Deployment Failed: ${statusRaw}"
                    }
                }
            }
        }

        stage('QA TakeOver') {
            steps {
                sh """
                curl -s -X POST \
                https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${SEMANTIC_MODEL_ID}/Default.TakeOver \
                -H "Authorization: Bearer ${env.TOKEN}" \
                -H "Content-Length: 0"
                """
            }
        }

        stage('QA Bind Databricks Connection') {
            steps {
                script {

                    def dsPayload = [
                        updateDetails: [[
                            datasourceSelector: [
                                datasourceType: "Extension",
                                connectionDetails: [
                                    extensionDataSourceKind: "Databricks",
                                    extensionDataSourcePath: [
                                        host: "adb-7405618110977329.9.azuredatabricks.net",
                                        httpPath: "/sql/1.0/warehouses/334a2ae248719051"
                                    ]
                                ]
                            ],
                            connectionId: QA_CONNECTION_ID
                        ]]
                    ]

                    writeJSON file: 'qa_ds_payload.json', json: dsPayload

                    sh """
                    curl -s -X POST \
                    https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${SEMANTIC_MODEL_ID}/Default.UpdateDatasources \
                    -H "Authorization: Bearer ${env.TOKEN}" \
                    -H "Content-Type: application/json" \
                    -d @qa_ds_payload.json
                    """
                }
            }
        }

        stage('QA Refresh') {
            steps {
                sh """
                curl -s -X POST \
                https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${SEMANTIC_MODEL_ID}/refreshes \
                -H "Authorization: Bearer ${env.TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{"type":"Full"}'
                """
            }
        }
    }

    post {
        always {
            sh "rm -f model_payload.json qa_ds_payload.json"
        }
    }
}
