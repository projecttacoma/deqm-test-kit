# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
require 'byebug'
module DEQMTestKit
  # BulkImport test group ensure the fhir server can accept bulk data import requests
  class BulkImport < Inferno::TestGroup
    include BulkImportUtils
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
    }.freeze
    fhir_client do
      url :url
      headers custom_headers
    end
    # rubocop:disable Metrics:BlockLength
    test do
      title 'Ensure data can be accepted'
      id 'bulk-import-01'
      description 'Send the data to the server and the response is a 202'
      run do
        assert(measure_id, 
               'No measure selected. Run Measure Availability prior to running the bulk import test group.')
        fhir_read(:measure, measure_id)
        assert_valid_json(response[:body])
        fhir_operation("Measure/#{measure_id}/$submit-data", body: params, name: :submit_data)
        reply = fhir_client.send(:get, '')
        location_header = response[:headers].find { |h| h.name == 'content-location' }
        # temporary fix for extra 4_0_1
        polling_url = "#{url}/#{location_header.value.sub('4_0_1/', '')}"
        fhir_client do
          url polling_url
        end
        reply = fhir_client.send(:get, '')
        wait_time = 1
        start = Time.now
        seconds_used = 0
        timeout = 120
        loop do
          reply = nil
          begin
            reply = fhir_client.send(:get, '')
            # reply = fhir_client.client.get(polling_url)
          rescue RestClient::TooManyRequests => e
            reply = e.response
          end
          wait_time = get_retry_or_backoff_time(wait_time, response)
          seconds_used = Time.now - start
          # exit loop if we get a successful response or timeout reached
          break if (reply.code != 202 && reply.code != 429) || (seconds_used > timeout)

          sleep wait_time
        end
      end
    end
  end
  # rubocop:enable Metrics:BlockLength
end
