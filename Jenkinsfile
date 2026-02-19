pipeline {
    agent any

    environment {

        CLIENT_ID     = "5edcfcf8-9dbd-4c1b-a602-a0887f677e2e"
        CLIENT_SECRET = "_5S8Q~g5IB33yW~tq9lPokpO1pL~V-pHpMP-hbMr"
        TENANT_ID     = "6fbff720-d89b-4675-b188-48491f24b460"
    
        DEV_WORKSPACE_ID = "7df30383-ce60-4c58-bb8b-3270385c8e6b"
        QA_WORKSPACE_ID  = "ca6e2845-48dd-4852-8129-6b833bd5963c"
    
        MODEL_NAME       = "test-9053"
        MODEL_FOLDER     = "test-9053.SemanticModel"
    
        QA_CONNECTION_ID = "adbb9db8-da40-44c2-9cdb-1337c6f52f23"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'dev',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/vinayakdeokar/fabric_cicd.git'
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

                    def pbismBase64 = sh(
                        script: "base64 -w 0 ${MODEL_FOLDER}/definition.pbism",
                        returnStdout: true
                    ).trim()

                    def parts = [
                        [path: "definition.pbism",
                         payload: pbismBase64,
                         payloadType: "InlineBase64"]
                    ]

                    def tmdlFiles = sh(
                        script: "find ${MODEL_FOLDER}/definition -name '*.tmdl'",
                        returnStdout: true
                    ).trim().split("\n")

                    tmdlFiles.each { filePath ->
                        def relativePath = filePath.substring(
                            filePath.indexOf("definition/")
                        )

                        def fileBase64 = sh(
                            script: "base64 -w 0 ${filePath}",
                            returnStdout: true
                        ).trim()

                        parts << [
                            path: relativePath,
                            payload: fileBase64,
                            payloadType: "InlineBase64"
                        ]
                    }

                    writeJSON file: 'model_payload.json',
                        json: [
                            displayName: MODEL_NAME,
                            type: "SemanticModel",
                            definition: [parts: parts]
                        ]
                }
            }
        }

        stage('Deploy To QA Workspace') {
            steps {
                script {
        
                    def checkRaw = sh(script: """
                        curl -s \
                        -H 'Authorization: Bearer ${env.TOKEN}' \
                        https://api.fabric.microsoft.com/v1/workspaces/${QA_WORKSPACE_ID}/items
                    """, returnStdout: true)
        
                    def checkJson = readJSON(text: checkRaw)
        
                    def existingModel = checkJson.value.find {
                        it.displayName == MODEL_NAME
                    }
        
                    if (existingModel) {
        
                        def QA_MODEL_ID = existingModel.id
                        echo "Updating existing model: ${QA_MODEL_ID}"
        
                        sh """
                            curl -s -X POST \
                            https://api.fabric.microsoft.com/v1/workspaces/${QA_WORKSPACE_ID}/items/${QA_MODEL_ID}/updateDefinition \
                            -H 'Authorization: Bearer ${env.TOKEN}' \
                            -H 'Content-Type: application/json' \
                            -d @model_payload.json
                        """
        
                        env.SEMANTIC_MODEL_ID = QA_MODEL_ID
        
                    } else {
        
                        echo "Creating new model..."
        
                        def createRaw = sh(script: """
                            curl -s -X POST \
                            https://api.fabric.microsoft.com/v1/workspaces/${QA_WORKSPACE_ID}/items \
                            -H 'Authorization: Bearer ${env.TOKEN}' \
                            -H 'Content-Type: application/json' \
                            -d @model_payload.json
                        """, returnStdout: true)
        
                        def createJson = readJSON(text: createRaw)
                        env.SEMANTIC_MODEL_ID = createJson.id
                    }
                }
            }
        }


        stage('QA TakeOver') {
            steps {
                sh """
                    curl -s -X POST \
                    https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${env.QA_MODEL_ID}/Default.TakeOver \
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

                    writeJSON file: 'qa_ds_payload.json',
                        json: dsPayload

                    sh """
                        curl -s -X POST \
                        https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${env.QA_MODEL_ID}/Default.UpdateDatasources \
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
                    https://api.powerbi.com/v1.0/myorg/groups/${QA_WORKSPACE_ID}/datasets/${env.QA_MODEL_ID}/refreshes \
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
