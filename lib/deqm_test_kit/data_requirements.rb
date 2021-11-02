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
      parameter: [{}]
    }.freeze

    INVALID_ID = 'INVALID_ID'

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
        fhir_operation("Measure/#{measure_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01",
                       body: PARAMS, name: :data_requirements)
        assert_response_status(200)
        assert_resource_type(:library)
        assert_valid_json(response[:body])

        actual_dr = resource.dataRequirement

        actual_dr_strings = get_dr_comparison_list actual_dr

        # Search embedded cqf-ruler instance by identifier and version
        fhir_search(:measure, client: :embedded_client,
                              params: { name: measure_identifier, version: measure_version }, name: :measure_search)
        embedded_client_id = resource.entry[0].resource.id

        # Run data requirements operation on embedded cqf-ruler instance
        fhir_operation(
          "Measure/#{embedded_client_id}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01",
          body: PARAMS,
          client: :embedded_client
        )
        expected_dr = resource.dataRequirement

        expected_dr_strings = get_dr_comparison_list expected_dr

        diff = expected_dr_strings - actual_dr_strings

        # still output queries even if different from expected.
        # TODO: output queries only if pass once they align with cqf-ruler
        queries = get_data_requirements_queries(actual_dr)
        output queries_json: queries.to_json

        # Ensure both data requirements results libraries are identical
        assert(diff.blank?,
               "Client data-requirements is missing expected data requirements for measure #{measure_id}: #{diff}")

        diff = actual_dr_strings - expected_dr_strings
        assert(diff.blank?,
               "Client data-requirements contains unexpected data requirements for measure #{measure_id}: #{diff}")
      end
    end

    test do
      title 'Check data requirements returns 400 for missing parameters'
      id 'data-requirements-02'
      description 'Data requirements returns 400 when periodStart and periodEnd parameters are omitted'

      run do
        # Run our data requirements operation on the test client server
        fhir_operation('Measure/TEST_ID/$data-requirements', body: PARAMS)
        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check data requirements returns 400 for invalid measure id'
      id 'data-requirements-03'
      description 'Data requirements returns 400 when passed a measure id which is not in the system'

      run do
        # Run our data requirements operation on the test client server
        fhir_operation(
          "Measure/#{INVALID_ID}/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01",
          body: PARAMS
        )
        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
