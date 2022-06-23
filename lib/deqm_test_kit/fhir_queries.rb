# frozen_string_literal: true

require_relative '../utils/data_requirements_utils'
require 'json'
require 'pry'

module DEQMTestKit
  # Perform fhir queries based on $data-requirements operation on test client
  class FHIRQueries < Inferno::TestGroup
    include DataRequirementsUtils
    id 'fhir_queries'
    title 'FHIR Queries'
    description 'Ensure fhir server can handle queries resulting from $data-requirements operation'
    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'measure-EXM130-7.3.000',
                        options: measure_options }

    fhir_client do
      url :url
    end
    # rubocop:disable Metrics/BlockLength
    test do
      title 'Valid FHIR Queries'
      id 'fhir-queries-01'
      description 'Queries resulting from a $data-requirements operation return 200 OK'
      makes_request :fhir_queries
      input :data_requirements_server_url
      input :measure_id, measure_id_args

      fhir_client :data_requirements_server do
        url :data_requirements_server_url
      end

      run do
        assert(measure_id,
               'No measure selected. Run Measure Availability prior to running the Submit Data test group.')
        fhir_operation("Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01",
                       client: :data_requirements_server)

        assert_response_status(200)
        assert_resource_type(:library)
        assert_valid_json(response[:body])
        actual_dr = resource.dataRequirement
        queries = get_data_requirements_queries(actual_dr)
        # Store responses to run assertions on later to ensure all requests go through before failure
        responses = queries.map do |q|
          fhir_search(q[:endpoint], params: q[:params])
          { response: response,
            query_string: "/#{q[:endpoint]}#{q[:params].size.positive? ? '?' : ''}#{URI.encode_www_form(q[:params])}" }
        end
        responses.each do |r|
          assert(r[:response][:status] == 200,
                 "Expected response code 200, received: #{r[:response][:status]} for query: #{r[:query_string]}")
          assert_valid_json(r[:response][:body],
                            "Received invalid JSON body on query response for query: #{r[:query_string]}")
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
