import logging
from apache_beam.ml.inference.base import RunInference
from apache_beam.ml.inference.vllm_inference import VLLMCompletionsModelHandler
from apache_beam.ml.inference.base import PredictionResult
from apache_beam.io.gcp.bigquery import ReadFromBigQuery, WriteToBigQuery
import apache_beam as beam

class FormatOutput(beam.DoFn):
  def process(self, element, *args, **kwargs):
    yield "Input: {input}, Output: {output}".format(input=element.example, output=element.inference)

query = 'select content from `dataflow-autotuning.rgagnon_sample_data.hacker_news`;'
# Specify the model handler, providing a path and the custom inference function.
model_handler = VLLMCompletionsModelHandler('google/gemma-2-2b-it')

with beam.Pipeline(options=options) as p:
    prompts = (p
               | 'ReadFromBigQuery' >> ReadFromBigQuery(query=query, use_standard_sql=True)
               | beam.Map(lambda row: row['content'])
               )

    def extract_inference_text(element):
        try:
            inference_text = element.inference.choices[0].text if element.inference.choices else "No inference text"
            return {"input": element.example, "output": inference_text}
        except Exception as e:
            return {"input": element.example, "output": f"Error extracting inference: {e}"}

    inference_results = (prompts
                         | 'RunInference' >> RunInference(model_handler)
                         | beam.Map(extract_inference_text))

    _ = (inference_results
         | 'WriteToBigQuery' >> WriteToBigQuery(
             table='dataflow-autotuning.rgagnon_sample_data.gemma_vllm_inference',
             schema='input:STRING, output:STRING',
             write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE,
             create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
         )
         )
