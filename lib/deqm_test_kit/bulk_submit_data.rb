# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
require 'json'

module DEQMTestKit
  # BulkImport test group - ensure the FHIR server can accept bulk data import requests
  class BulkSubmitData < Inferno::TestGroup
    include BulkImportUtils
    id 'bulk_submit_data'
    title 'Bulk Submit Data'
    description %(
      This test inspects the response to POST [base]/$submit-data and GET [bulk status endpoint]
      to ensure that the FHIR server can accept bulk data import requests when a measure
      is specified
    )

    default_url = 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir/$export'
    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_mappings = JSON.parse(File.read('./lib/fixtures/measureCanonicalUrlMapping.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options,
                        title: 'Measure ID' }

    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance"}', prefer: 'respond-async' }

    fhir_client do
      url :url
      headers custom_headers
    end
    # rubocop:disable Metrics/BlockLength
    test do
      title 'Ensure FHIR server can accept bulk data import requests for given measure'
      id 'bulk-submit-data-01'
      description %(POST request to $submit-data returns 202 response,
      GET request to bulk status endpoint returns 200 response)

      input :measure_id, **measure_id_args
      input :exportUrl, title: 'Data Provider URL',
                        description: %(Export Server to use for bulk import requests), default: default_url
      run do
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the bulk submit data test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        params = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureReport',
              resource: {
                resourceType: 'MeasureReport',
                measure: measure_mappings[measure_id]
              }
            },
            {
              name: 'exportUrl',
              valueUrl: exportUrl
            }
          ]
        }.freeze

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
      # rubocop:enable Metrics/BlockLength
    end
  end
end
