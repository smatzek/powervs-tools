# PowerVS tools
This repository is a collection of scripts and other artifacts that work with [IBM Power Virtual Server](https://cloud.ibm.com/power/overview).

In the scripts and documentation in this repository the terms VSI (virtual server instance) and LPAR (Logical Partition) should be considered analogous.

# Scripts
With the exception of the cloud object storage upload script, the scripts do not rely on each other or a common utility function script. While there is a lot of common code in the scripts they have been kept separate so users can choose only the scripts they want to use without having to work out cross-script dependencies.

**Script usage statements:** The [scripts](./scripts/) generally provide a usage statement when called with no parameters or the `-h` parameter.

**Script software requirements:**
All of the scripts require [jq](https://jqlang.github.io/jq/) to parse CLI or API output. To interact with PowerVS the scripts use either API calls with `curl` or use [IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started) with the PowerVS CLI plugin (`ibmcloud plugin install power-iaas`). The scripts that require the IBM Cloud CLI will check for it at runtime. The browser based [IBM Cloud Shell](https://www.ibm.com/products/cloud-shell) can also be used in place of a local install of the IBM Cloud CLI.


## IBM i cloud object storage upload
The [IBM i COS upload](./scripts/cos-upload) "script" is a collection of two bash scripts and a CL script that provide a reusable utility for uploading files to IBM Cloud Object Storage (COS).

The CL portion allows COS uploads to be more easily tied into processes, for example generating PDFs versions of BRMS recovery reports uploading the reports to COS for safe keeping and controlled retention.

While the CL portion is IBM i specific, the shell scripts could easily be adapted for AIX and Linux.

See the [COS upload README](./scripts/cos-upload/README.md) for a deeper description of this script collection.

## Change storage tier of all volumes attached to a VSI
There are two scripts to change the storage tier of all volumes attached to a VSI.

### changeVSIVolumeTier.sh
The [changeVSIVolumeTier.sh](./scripts/changeVSIVolumeTier.sh) script uses the IBM Cloud CLI to change the volume tier. It is a general purpose script that can target different workspaces and VSIs.

### changeVSIVolumeTierWithAPI.sh
The [changeVSIVolumeTierWithAPI.sh](./scripts/changeVSIVolumeTierWithAPI.sh) script uses is written using `curl` and `jq` and does not require the IBM Cloud CLI. This allows it to be run from within an IBM i or AIX VSI and could be used as part of a scheduled job to change the volume tiers on a time schedule. For example, the volume speed could be increased before batch processing and decreased when it is finished. For IBM i, an adapted version of the [cos-upload CL program](./scripts/cos-upload/cos-upload.clp) could be used to make IBM i job scheduling easier.

Since the script is intended to be called from the VSI that it is modifying some of its inputs are inside the script itself as variables that should be set. This make the CL code that calls the script simpler. See the script source for more information.

## Change a VSI's CPU and memory
The [setVSIProcMem.sh](./scripts/setVSIProcMem.sh) script is used to change a VSI's processor and memory. It is written using `curl` and `jq` and does not require the IBM Cloud CLI. This allows it to be run from within an IBM i or AIX VSI and could be used as part of a scheduled job to increase or decrease proccessors and memory on a time schedule. For IBM i, an adapted version of the [cos-upload CL program](./scripts/cos-upload/cos-upload.clp) could be used to make IBM i job scheduling easier.

Since the script is intended to be called from the VSI that it is modifying some of its inputs are inside the script itself as variables that should be set. This make the CL code that calls the script simpler. See the script source for more information.

## Get a mapping of WWN/serial number to PowerVS volume name for all of a VSI's volumes
The [getLPARVolumeWWNs.sh](./scripts/getLPARVolumeWWNs.sh) script outputs a table containing the mapping between a volume's serial number or WWN and its name in PowerVS for all volumes attached to a given VSI. This is useful to map disks as seen in the operating system to the corresponding PowerVS volume.

## Get VSI SRCs
The [getSRCs.sh](./scripts/getSRCs.sh) script repeatedly displays a VSI's SRCs until it is stopped with CTRL-C.

## Tag a VSI and all attached volumes
The [tagLPARandVolumes.sh](./scripts/tagLPARandVolumes.sh) script attaches or detaches user tags on a VSI and all its attached storage volumes. User tags can be used to help with billing analysis and resource filtering. See [this blog](https://community.ibm.com/community/user/blogs/samuel-matzek1/2025/11/17/tagging-powervs-vsis-and-volumes-for-cost-analysis) for examples on how tagging can be used for cost analysis.

## Target a PowerVS workspace by name in IBM Cloud CLI
The [icpiwstg](./scripts/icpiwstg) script is a simple utility script that targets a PowerVS workspace by name using the IBM Cloud PowerVS CLI. The IBM Cloud CLI command `ic pi ws tg` targets a specific workspace to operate against, but it requires you to specify the workspace CRN. The `icpiwstg` script allows you to target by name.

## Batch creation and attachment of volumes
The [addVolumes.sh](./scripts/addVolumes.sh) script creates and attaches multiple volumes to a VSI. Since it uses the bulk PowerVS CLI volume operations it can create multiple volumes in parallel, wait until they are all created, and then do a bulk attach to the VSI without requiring the user to do manual volume readiness checks on many volumes.

## Get SSL certificates from a server
The [getSSLCerts.sh](./scripts/getSSLCerts.sh) script retrieves certificates (CA certs and server certs) from the specified host and port and saves them to PEM files. While this script will run on AIX and Linux, it is particularly useful for fetching CA certificates and writing them to IFS on IBM i. This allows for easier adding of CAs to certificate stores in IBM i Digital Certificate Manager (DCM) because the PEM is fetched and stored on IFS which and the path to the PEM can be specified in DCM's import certificate screen.

When the script runs, it outputs the PEM file name and the subject of the certificate in the file. This allows the user to correlate the file with the CA that is needed for import. In the following example, the `cert2.pem` file is associated with the `Let's Encrypt CN=13` intermediate CA.

```
cert1.pem: subject=CN = target.server.fqdn.com
cert2.pem: subject=C = US, O = Let's Encrypt, CN = R13
```