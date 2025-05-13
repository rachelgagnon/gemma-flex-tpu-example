# gemma-flex-tpu-example
Example of running Gemma Dataflow Flex Template on a TPU Accelerator.

## RunInference on Dataflow streaming with Gemma and Flex Templates
Gemma is a family of lightweight, state-of-the-art open models built from research and technology used to create the Gemini models. You can use Gemma models in your Apache Beam inference pipelines with the RunInference transform.

This example demonstrates how to use a Gemma model running on Pytorch in a streaming Dataflow pipeline that has Pub/Sub sources and sinks. This pipeline is deployed by using Flex Templates.

For more information about using RunInference, see Get started with AI/ML pipelines in the Apache Beam documentation.

## Setup Steps

### Enable Google Cloud services
This workflow uses multiple Google Cloud products, including Dataflow, Pub/Sub, Google Cloud Storage, and Artifact Registry. Before you start the workflow, create a Google Cloud project that has the following services enabled:

Dataflow
Pub/Sub
Compute Engine
Cloud Logging
Google Cloud Storage
Google Cloud Storage JSON
Cloud Build
Datastore
Cloud Resource Manager
Artifact Registry
Using these services incurs billing charges.

### Your Google Cloud project also needs to have TPU quota.

### Download and save the model
Save a version of the Gemma 2B model. Downloaded the model from Kaggle. This download is a .tar.gz archive. Extract the archive into a directory and name it pytorch_model.

### Create a cloud storage bucket
Create a cloud storage bucket for your flex template.

### Create Pub/Sub topic for output
To create your Pub/Sub sink, follow the instructions in Create a Pub/Sub topic in the Google Cloud documentation. For this example, create one output topic. The output subscription will allow you to see the output from the pipeline during and after execution.

### Create a custom container
To build a custom container, use Docker. This repository contains a Dockerfile that you can use to build your custom container. To build and push a container to Artifact Registry by using Cloud Build.

gcloud builds submit --tag us-central1-docker.pkg.dev/dataflow-build/rgagnon/gemma-tpu-vllm
gcloud builds submit --tag gcr.io/dataflow-build/rgagnon/gemma-tpu-vllm

## Build the Flex Template
Run the following code from the directory to build the Dataflow flex template.

gcloud dataflow flex-template build gs://dataflow-autotuning/tpu_flex_templates/gemma-vllm-config.json \
  --image gcr.io/dataflow-build/rgagnon/gemma-tpu-vllm\
  --sdk-language "PYTHON" \
  --metadata-file metadata.json \
  --project dataflow-autotuning

## Start the pipeline
To start the Dataflow streaming job, run the following code from the directory.

gcloud dataflow flex-template run "gemma-vllm-`date +%Y%m%d-%H%M%S`" \
  --template-file-gcs-location gs://dataflow-autotuning/tpu_flex_templates/gemma-vllm-config.json \
  --region us-central1 \
  --temp-location gs://dataflow-autotuning/tmp \
  --staging-location gs://dataflow-staging-us-central1-649008530395 \
  --parameters responses_topic=projects/dataflow-autotuning/topics/gemma-output-topic \
  --parameters device="TPU" \
  --parameters sdk_container_image=gcr.io/dataflow-build/rgagnon/gemma-tpu-vllm \
  --parameters disk_size_gb=500 \
  --project dataflow-autotuning \
  --additional-experiments "worker_accelerator=type:tpu-v5p-slice;topology:2x2x1" \
  --worker-machine-type "ct5lp-hightpu-4t" \
  --additional-pipeline-options no_use_multiple_sdk_containers=true

## Check the response
The Dataflow job outputs the response to the Pub/Sub sink topic. To check the response from the model, you can manually pull messages from the destination topic. For more information, see Publish messages in the Google Cloud documentation.

## Clean up resources
To avoid incurring charges to your Google Cloud account for the resources used in this example, clean up the resources that you created.

## Cancel the streaming Dataflow job.
Optional: Archive the streaming Dataflow job.
Delete the Pub/Sub topic and subscriptions.
Delete the custom container from Artifact Registry.
Delete the created GCS bucket.