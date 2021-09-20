# frozen_string_literal: true

require_relative '../utils/data_requirements_utils'

module DEQMTestKit
  # GET [base]/Measure/CMS146/$data-requirements?periodStart=2014&periodEnd=2014
  class DataRequirements < Inferno::TestGroup
    include DataRequirementsUtils

    id 'data_requirements'
    title 'Data Requirements'
    description 'Ensure fhir server can respond to the $data-requirements request'

    fhir_client do
      url :url
    end

    fhir_client :embedded_client do
      url 'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
    end

    PARAMS = {
      resourceType: 'Parameters',
      parameter: [{
        periodStart: '2019-01-01',
        periodEnd: '2019-12-31'

      }]
    }.freeze

    # rubocop:disable Metrics/BlockLength
    test do
      title 'Check data requirements against expected return'
      id 'data-requirements-01'
      description 'Data requirements on the fhir test server match the data requirements of our embedded client'
      makes_request :data_requirements
      output :queries_json
      input :measure_id

      run do
        # Get measure resource from client
        fhir_read(:measure, measure_id)
        assert_response_status(200)
        assert_resource_type(:measure)
        assert_valid_json(response[:body])
        measure_identifier = resource.name
        measure_version = resource.version

        # Run our data requirements operation on the test client server
        fhir_operation("Measure/#{measure_id}/$data-requirements", body: PARAMS, name: :data_requirements)
        assert_response_status(200)
        assert_resource_type(:library)
        assert_valid_json(response[:body])

        library = JSON.parse(response[:body])
        actual_dr = library['dataRequirement']

        actual_dr_strings = get_dr_comparison_list actual_dr

        # Search embedded cqf-ruler instance by identifier and version
        fhir_search(:measure, client: :embedded_client,
                              params: { name: measure_identifier, version: measure_version }, name: :measure_search)
        measure_bundle = JSON.parse(response[:body])

        embedded_client_id = measure_bundle['entry'][0]['resource']['id']

        # Run data requirements operation on embedded cqf-ruler instance
        fhir_operation("Measure/#{embedded_client_id}/$data-requirements", body: PARAMS, client: :embedded_client)
        expected_library = JSON.parse(response[:body])
        expected_dr = expected_library['dataRequirement']

        expected_dr_strings = get_dr_comparison_list expected_dr

        diff = expected_dr_strings - actual_dr_strings

        # Ensure both data requirements results libraries are identical
        assert(diff.blank?,
               "Client data-requirements is missing expected data requirements for measure #{measure_id}: #{diff}")

        diff = actual_dr_strings - expected_dr_strings
        assert(diff.blank?,
               "Client data-requirements contains unexpected data requirements for measure #{measure_id}: #{diff}")
        queries = get_data_requirements_queries(actual_dr)
        output queries_json: queries.to_json
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
