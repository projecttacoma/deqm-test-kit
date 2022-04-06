# rubocop:disable Style/FrozenStringLiteralComment

require_relative '../utils/bulk_import_utils'
module DEQMTestKit
  # BulkImport test group - ensure the FHIR server can accept bulk data import requests
  class BulkImport < Inferno::TestGroup
    include BulkImportUtils
    id 'bulk_import'
    title 'Non-Measure-Specific Bulk Import'
    description %(
        This test inspects the response to POST \[base\]/$import and GET \[bulk status endpoint\]
        to ensure that the FHIR server can accept bulk data import requests in the
        non-measure-specific case
      )

    default_url = 'https://bulk-data.smarthealthit.org/eyJlcnIiOiIiLCJwYWdlIjoxMDAwMCwiZHVyIjoxMCwidGx0IjoxNSwibSI6MSwic3R1IjozLCJkZWwiOjB9/fhir/$export'

    fhir_client do
      url :url
    end
    # rubocop:disable Metrics/BlockLength
    test do
      title 'Ensure FHIR server can accept bulk data import requests'
      id 'bulk-import-01'
      description %(POST request to $import returns 202 response,
      GET request to bulk status endpoint returns 200 response)

      input :types, optional: true,
                    title: 'FHIR resource types',
                    description: %(string of comma-delimited FHIR resource types used to filter
                    exported resources in bulk import operation)

      params = {
        resourceType: 'Parameters',
        parameter: [
          {
            name: 'exportUrl',
            valueUrl: default_url
          }
        ]
      }
      run do
        params[:parameter][0][:valueUrl] = default_url + "?_type=#{types}" if types.length.positive?
        fhir_operation('$import', body: params, name: :bulk_import)
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
    # rubocop:enable Metrics/BlockLength
  end
end
# rubocop:enable Style/FrozenStringLiteralComment
