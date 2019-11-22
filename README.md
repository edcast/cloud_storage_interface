# Cloud Storage Interface

The concept behind this gem was to support multiple cloud storgae options to upload images,csv's or pdsf. At Edcast, we have several micro-service which uses there own version of aws s3 gems to upload files. Going forward, with minimum change, rails app can upload, download, list objects from bucket that is hosted on either of cloud options. We don't have plan to add support for other cloud storgage but it would be fairly straight forward. At the moment, This gem supports

  - AWS S3
  - GCP GCS


# How to use?

Depending on the cloud option, constant can be set as below
### AWS
Make sure, you've set below envs are set before you begin to use
 - AWS_ACCESS_KEY_ID
 - AWS_SECRET_ACCESS_KEY

### GCP
GCP authentication expects below env is set with the path to the credentials file
`GOOGLE_APPLICATION_CREDENTIALS=path/to/json/file`.

In Kubernetes env, we've setup through config map. A sample example on how to set secret key is mentioned [here](https://github.com/GoogleCloudPlatform/kubernetes-engine-samples/blob/master/cloud-pubsub/deployment/pubsub-with-secret.yaml). you need to mound the content of file to a path and make sure that path is available to app through env variable. A samepl deployment would like this
```yml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: gcp-backend
  name: gcp-backend
  namespace: default
spec:
  minReadySeconds: 45
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: gcp-backend
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: gcp-backend
    spec:
      containers:
      - args:
        - -c
        - bundle exec puma -C config/puma.rb -p 80
        command:
        - /bin/sh
        envFrom:
        - configMapRef:
            name: gcp-backend
        - secretRef:
            name: gcp-backend
        image: repo/app_repo:latest
        imagePullPolicy: Always
        name: gcp-backend
        volumeMounts:
        - name: google-cloud-key
          mountPath: /var/secrets/google/google-sa.json
          subPath: google-sa.json
        ports:
        - containerPort: 5000
          protocol: TCP
        resources:
          limits:
            cpu: "1"
            memory: 2000Mi
          requests:
            cpu: 800m
            memory: 1500Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: regcred
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - configMap:
          defaultMode: 420
          name: gcp-backend-nginx
        name: nginx
      - name: google-cloud-key
        secret:
          secretName: google-sa-key
```

And in secrets/configmap
```yml
GOOGLE_APPLICATION_CREDENTIALS=/var/secrets/google/google-sa.json
```

 MAke sure service account has permissions to access GCS.

 ### Ruby on Rails App Use

```ruby
#AWS client can be initalized as below. if only AWS is required, comment out GCS line
AWS_S3_STORAGE_ADAPTER = CloudStorageInterface::AwsS3Interface.new

# initialize GCS client
unless Settings.google_application_credentials.blank?
  GCS_STORAGE_ADAPTER = CloudStorageInterface::GcpGcsInterface.new
end

#Depending on the cluster option, load the appropriate constant
CLOUD_STORAGE_ADAPTER = if Settings.use_gcs_for_file_upload
  GCS_STORAGE_ADAPTER
else
  AWS_S3_STORAGE_ADAPTER
end
```

## Public methods
List of public methods can be found [here](https://github.com/edcast/cloud_storage_interface/blob/master/lib/cloud_storage_interface/abstract_interface.rb)

- upload_file
- presigned_url
- download_file
- delete_file!
- file_exists?
- list_objects
- public_url
- presigned_post
- object_details

Implementation details can be found linked github page.

## Future work:
Support more public methods as when new need arise. If you plan to support Azure, Digital Ocean or any other cloud platform which not supported by this gem, can be extended very easily.

Define all public methods in separate interface just like it is done for aws s3 and gcp gcs.
