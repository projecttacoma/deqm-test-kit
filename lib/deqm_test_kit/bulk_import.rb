# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
module DEQMTestKit
  # BulkImport test group ensure the fhir server can accept bulk data import requests
  class BulkImport < Inferno::TestGroup
    id 'bulk_import'
    title 'Bulk Import'
    description 'Ensure the fhir server can accept bulk data import requests'

    input :measure_id
    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance"}', prefer: 'respond-async' }
    params = {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'measureReport',
          resource: {
            resourceType: 'MeasureReport',
            measure: 'http://hl7.org/fhir/us/cqfmeasures/Measure/EXM130'
          }
        },
        {
          name: 'exportURL',
          valueString: 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir'
        }
      ]
    }
    fhir_client do
      url :url
      headers custom_headers
    end
    test do
      title 'Ensure data can be accepted'
      id 'bulk-import-01'
      description 'Send the data to the server and the response is a 202 (or is it?)'
      run do
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the bulk import test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        fhir_operation("Measure/#{measure_id}/$submit-data", body: params, name: :submit_data)
        reply = fhir_client(:url).send(:get, '$bulkstatus')
        polling_url = url + reply.headers('Content-Location')
        fhir_operation('$bulkstatus', polling_url)
        loop_on_polling(polling_url)
      end
    end
  end
end
