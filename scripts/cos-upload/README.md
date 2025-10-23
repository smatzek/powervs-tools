# IBM i COS upload scripts

The [IBM i COS upload](./cos-upload) "script" is a collection of 2 bash scripts and a CL script that provide a reusable utility for uploading files to IBM Cloud Object Storage (COS).

The [CL program](./cos-upload.clp) allows the upload to be called by other CL code and used as a scheduled job. This allows for it to be tied into processes like BRMS saves, generating PDFs of recovery reports, and uploading the reports to COS for safe keeping and controlled retention.

The CL program in turn calls a ["helper" script](./cos-upload-helper.sh) in PASE which handles the COS object naming, some parameter defaulting and allows the CL code to be simpler.

The helper script then calls the general utility [cos-upload.sh](./cos-upload.sh) script which uses the `curl` and `jq` commands in the [IBM i open source packages](https://ibmi-oss-docs.readthedocs.io/en/latest/README.html) to communicate with IBM Cloud for authentication and upload.

## IBM Cloud IAM policy set up
The COS upload script uses an IBM Cloud IAM API key to log in and gain access to write to the bucket. This is different from the HMAC keys that are often used to access object storage buckets.

To limit the amount of access the API key has, an IBM Cloud IAM Service ID can be used, and the service ID's authority can be scoped to a single policy that allows it to write objects only to a specific bucket. The authority can be scoped such that the service ID can only write objects but not list bucket contents or read objects in the bucket.

To limit a policy to a specific bucket use the following settings in the "Assign Access" interface:

1. Service: Cloud Object Storage
2. Resources, choose Specific Resource
3. Choose the Service Instance attribute, choose "string equals" and select the COS instance containing the bucket.
4. Add another condition. Choose attribute "Resource ID", choose "string equals", and specify the name of the bucket for the value.
5. Add another condition. Choose attribute "Resource type", "string equals", and specify "bucket" for the value.
6. For "Roles and Actions" grant only the "Object Writer" service action.

A table view of the settings:
| Setting             | Comparator    | Value                          |
| ------------------- | ------------- | ------------------------------ |
| Specific Resources  | N/A           | Selected                       |
| Service Instance    | string equals | COS instance containing bucket |
| Resource ID         | string equals | your-bucket-name               |
| Resource type       | string equals | "bucket"                       |
| Service access Role | N/A           | Object Writer                  |
