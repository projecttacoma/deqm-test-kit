# frozen_string_literal: true

require_relative '../utils/bulk_import_utils'
module DEQMTestKit
  # BulkImport test group ensure the fhir server can accept bulk data import requests
  class BulkImport < Inferno::TestGroup
    include BulkImportUtils
    id 'bulk_import'
    title 'Non-Measure-Specific Bulk Import'
    description 'Ensure the fhir server can accept bulk data import requests in the non-measure-specific case'

    params = {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'exportUrl',
          valueString: 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir/$export'
        }
      ]
    }.freeze
    fhir_client do
      url :url
    end
    test do
      title 'Ensure data can be accepted'
      id 'bulk-import-01'
      description 'POST to $import and the response is a 202'
      run do
        fhir_operation('$import', body: params, name: :bulk_import)
        location_header = response[:headers].find { |h| h.name == 'content-location' }
        # temporary fix for extra 4_0_1
        polling_url = "#{url}/#{location_header.value.sub('4_0_1/', '')}"
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
