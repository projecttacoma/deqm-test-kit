# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
module DEQMTestKit
  # BulkImport test group ensure the fhir server can accept bulk data import requests
  class BulkSubmitData < Inferno::TestGroup
    include BulkImportUtils
    id 'bulk_submit_data'
    title 'Bulk Submit Data'
    description 'Ensure the fhir server can accept bulk data import requests when a measure is specified'

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
          name: 'exportUrl',
          valueUrl: 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir'
        }
      ]
    }.freeze
    fhir_client do
      url :url
      headers custom_headers
    end
    test do
      title 'Ensure data can be accepted'
      id 'bulk-submit-data-01'
      description 'POST to $submit-data returns 202 response, bulk status endpoint returns 200 response'
      run do
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the bulk import test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        fhir_operation("Measure/#{measure_id}/$submit-data", body: params, name: :submit_data)
        location_header = response[:headers].find { |h| h.name == 'content-location' }
        polling_url = location_header.value
        wait_time = 1
        start = Time.now
        seconds_used = 0
        timeout = 120
        loop do
          get(polling_url)
          wait_time = get_retry_or_backoff_time(wait_time, response)
          seconds_used = Time.now - start
          # exit loop if we get a response  we don't expect or timeout reached
          break if (response[:status] != 202 && response[:status] != 429) || (seconds_used > timeout)

          sleep wait_time
        end
        assert_response_status(200)
      end
    end
  end
end
