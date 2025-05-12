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

### Your Google Cloud project also needs to have Nvidia L4 GPU quota. For more information, see GPU quota in the Google Cloud documentation.

### Download and save the model
Save a version of the Gemma 2B model. Downloaded the model from Kaggle. This download is a .tar.gz archive. Extract the archive into a directory and name it pytorch_model.

### Create a cloud storage bucket
Create a cloud storage bucket for your flex template.

### Create Pub/Sub topic for output
To create your Pub/Sub sink, follow the instructions in Create a Pub/Sub topic in the Google Cloud documentation. For this example, create one output topic. The output subscription will allow you to see the output from the pipeline during and after execution.

# Code overview
This section provides details about the custom model handler and the formatting DoFn used in this example.

### Custom model handler
This example defines a custom model handler that loads the model. The model handler constructs a configuration object and loads the model's checkpoint from the local filesystem. Because this approach differs from the PyTorch model loading process followed in the Beam PyTorch model handler, a custom implementation is necessary.

To customize the behavior of the handler, implement the following methods: load_model, validate_inference_args, and share_model_across_processes.

The PyTorch implementation of the Gemma models has a generate method that generates text based on a prompt. To route the prompts correctly, use this function in the run_inference function.

class GemmaPytorchModelHandler(ModelHandler[str, PredictionResult,
                                            GemmaForCausalLM]):
    def __init__(self,
                 model_variant: str,
                 checkpoint_path: str,
                 tokenizer_path: str,
                 device: Optional[str] = 'cpu'):
        """ Implementation of the ModelHandler interface for Gemma-on-Pytorch
        using text as input.

        Example Usage::

          pcoll | RunInference(GemmaPytorchHandler())

        Args:
          model_variant: The Gemma model name.
          checkpoint_path: the path to a local copy of gemma model weights.
          tokenizer_path: the path to a local copy of the gemma tokenizer
          device: optional. the device to run inference on. can be either
            'cpu' or 'gpu', defaults to cpu. 
        """
        model_config = get_config_for_2b(
        ) if "2b" in model_variant else get_config_for_7b()
        model_config.tokenizer = tokenizer_path
        model_config.quant = 'quant' in model_variant
        model_config.tokenizer = tokenizer_path

        self._model_config = model_config
        self._checkpoint_path = checkpoint_path
        if device == 'GPU':
            logging.info("Device is set to CUDA")
            self._device = torch.device('cuda')
        else:
            logging.info("Device is set to CPU")
            self._device = torch.device('cpu')
        self._env_vars = {}

    def load_model(self) -> GemmaForCausalLM:
        """Loads and initializes a model for processing."""
        torch.set_default_dtype(self._model_config.get_dtype())
        model = GemmaForCausalLM(self._model_config)
        model.load_weights(self._checkpoint_path)
        model = model.to(self._device).eval()
        return model
Formatting DoFn
The output from a keyed model handler is a tuple of the form (key, PredictionResult). To format that output into a string before sending it to the answer Pub/Sub topic, use an extra DoFn.

| "Format output" >> beam.Map(
    lambda response: json.dumps(
        {"input": response.example, "outputs": response.inference}
    )
)

### Create a custom container
To build a custom container, use Docker. This repository contains a Dockerfile that you can use to build your custom container. To build and push a container to Artifact Registry by using Cloud Build.

in PSO sandbox:
gcloud builds submit --tag us-central1-docker.pkg.dev/data-analytics-pocs/rgagnon/gemma-tpu-image

Permission denied:
gcloud builds submit --tag us-central1-docker.pkg.dev/dataflow-build/rgagnon/gemma-tpu-image

gcloud builds submit --tag us-central1-docker.pkg.dev/dataflow-build/gemma-tpu-image:rgagnon-test

gcloud builds submit --tag gcr.io/dataflow-build/rgagnon/gemma-tpu-image

## Build the Flex Template
Run the following code from the directory to build the Dataflow flex template.

Replace $GCS_BUCKET with a Google Cloud Storage bucket.
Set SDK_CONTAINER_IMAGE to the name of the Docker image created previously.
$PROJECT is the Google Cloud project that you created previously.

gcloud dataflow flex-template build gs://dataflow-autotuning/tpu_flex_templates/gemma-gpu-config.json \
  --image gcr.io/dataflow-build/rgagnon/gemma-gpu-benchmarking\
  --sdk-language "PYTHON" \
  --metadata-file metadata.json \
  --project dataflow-autotuning

## Start the pipeline
To start the Dataflow streaming job, run the following code from the directory. Replace $TEMPLATE_FILE, $REGION, $GCS_BUCKET, $INPUT_SUBSCRIPTION, $OUTPUT_TOPIC, $SDK_CONTAINER_IMAGE, and $PROJECT with the Google Cloud project resources you created previously. Ensure that $INPUT_SUBSCRIPTION and $OUTPUT_TOPIC are the fully qualified subscription and topic names, respectively. It might take as much as 30 minutes for the worker to start up and to begin accepting messages from the input Pub/Sub topic.

gcloud dataflow flex-template run "gemma-flex-`date +%Y%m%d-%H%M%S`" \
  --template-file-gcs-location gs://dataflow-autotuning/tpu_flex_templates/gemma-gpu-config.json \
  --region us-central1 \
  --temp-location gs://dataflow-autotuning/tmp \
  --staging-location gs://dataflow-staging-us-central1-649008530395 \
  --parameters responses_topic=projects/dataflow-autotuning/topics/gemma-output-topic \
  --parameters device="GPU" \
  --parameters sdk_container_image=gcr.io/dataflow-build/rgagnon/gemma-gpu-benchmarking \
  --project dataflow-autotuning \
  --additional-experiments "worker_accelerator=type:nvidia-l4;count:1;install-nvidia-driver" \
  --worker-machine-type "g2-standard-4"

* note that this reservation is for one worker with 8 chips

## Check the response
The Dataflow job outputs the response to the Pub/Sub sink topic. To check the response from the model, you can manually pull messages from the destination topic. For more information, see Publish messages in the Google Cloud documentation.

## Clean up resources
To avoid incurring charges to your Google Cloud account for the resources used in this example, clean up the resources that you created.

## Cancel the streaming Dataflow job.
Optional: Archive the streaming Dataflow job.
Delete the Pub/Sub topic and subscriptions.
Delete the custom container from Artifact Registry.
Delete the created GCS bucket.