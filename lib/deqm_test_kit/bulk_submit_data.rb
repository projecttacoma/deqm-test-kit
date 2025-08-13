# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
require 'json'

module DEQMTestKit
  # BulkImport test group - ensure the FHIR server can accept bulk data import requests
  class BulkSubmitData < Inferno::TestGroup
    # module for shared code for measure availability assertions and requests
    module BulkSubmitDataHelpers
      def selected_measure_id
        return custom_measure_id.strip if measure_id == 'Other' && custom_measure_id&.strip&.length&.positive?

        measure_id
      end
    end
    include BulkImportUtils
    id 'bulk_submit_data'
    title 'Bulk Submit Data'
    description "
      This test inspects the response to POST [base]/$bulk-submit-data and GET [bulk status endpoint]
      to ensure that the FHIR server can accept bulk data import requests when a measure
      is specified
    "

    default_url = 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibToxLCJzdHUiOjMsImRlbCI6MH0/fhir/$export'
    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_mappings = JSON.parse(File.read('./lib/fixtures/measureCanonicalUrlMapping.json'))
    measure_id_args = {
      type: 'radio',
      optional: false,
      default: 'ColorectalCancerScreeningsFHIR',
      options: measure_options,
      title: 'Measure Title'
    }
    custom_measure_id_args = {
      type: 'text',
      optional: true,
      title: 'Custom Measure ID',
      description: 'If you selected "Other" above or want to provide a custom Measure ID, enter it here.'
    }

    custom_headers = { 'X-Provenance': '{"resourceType": "Provenance"}', prefer: 'respond-async' }

    fhir_client do
      url :url
      headers custom_headers
    end
    # rubocop:disable Metrics/BlockLength
    test do
      include BulkSubmitDataHelpers
      title 'Ensure FHIR server can accept bulk data import requests for given measure'
      id 'bulk-submit-data-accepts-submit-requests'
      description %(POST request to $bulk-submit-data returns 202 response,
      GET request to bulk status endpoint returns 200 response)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :exportUrl, title: 'Data Provider URL',
                        description: %(Export Server to use for bulk import requests), default: default_url
      run do
        assert(selected_measure_id,
               'No measure selected. Run Measure Availability prior to running the bulk submit data test group.')
        fhir_read(:measure, selected_measure_id)
        assert_valid_json(response[:body])
        params = {
          resourceType: 'Parameters',
          parameter: [
            {
              name: 'measureReport',
              resource: {
                resourceType: 'MeasureReport',
                measure: measure_mappings[selected_measure_id]
              }
            },
            {
              name: 'exportUrl',
              valueUrl: exportUrl
            }
          ]
        }.freeze

        fhir_operation("Measure/#{selected_measure_id}/$bulk-submit-data", body: params, name: :submit_data)
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
