# frozen_string_literal: true

require_relative '../utils/data_requirements_utils'
require 'json'

module DEQMTestKit
  # GET [base]/Measure/CMS146/$data-requirements?periodStart=2014&periodEnd=2014
  class DataRequirements < Inferno::TestGroup
    include DataRequirementsUtils
    # module for shared code for $data-requirements assertions and requests
    module DataRequirementsHelpers
      def assert_dr_failure(expected_status: 400)
        assert_error(expected_status)
      end
    end
    id 'data_requirements'
    title 'Data Requirements'
    description 'Ensure FHIR server can respond to the $data-requirements request'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'ColorectalCancerScreeningsFHIR',
                        options: measure_options, title: 'Measure Title' }

    PARAMS = {
      resourceType: 'Parameters',
      parameter: [{}]
    }.freeze

    INVALID_ID = 'INVALID_ID'

    # rubocop:disable Metrics/BlockLength
    test do
      title 'Check data requirements against expected return'
      id 'data-requirements-01'
      description 'Data requirements on the FHIR test server match the data requirements of reference server'
      makes_request :data_requirements
      output :queries_json
      input :measure_id, **measure_id_args
      input :data_requirements_reference_server

      fhir_client :dr_reference_client do
        url :data_requirements_reference_server
      end

      run do
        # Get measure resource from client
        fhir_read(:measure, measure_id)
        assert_response_status(200)
        assert_resource_type(:measure)
        assert_valid_json(response[:body])
        measure_identifier = resource.name
        measure_version = resource.version

        # Run our data requirements operation on the test client server
        fhir_operation("Measure/#{measure_id}/$data-requirements",
                       body: PARAMS, name: :data_requirements)
        assert_response_status(200)
        assert_resource_type(:library)
        assert_valid_json(response[:body])

        actual_dr = resource.dataRequirement

        actual_dr_strings = get_dr_comparison_list actual_dr

        # Search reference server by identifier and version
        fhir_search(:measure, client: :dr_reference_client,
                              params: { name: measure_identifier, version: measure_version }, name: :measure_search)
        reference_measure_id = resource.entry[0].resource.id

        # Run data requirements operation on reference server
        fhir_operation(
          "Measure/#{reference_measure_id}/$data-requirements",
          body: PARAMS,
          client: :dr_reference_client
        )
        expected_dr = resource.dataRequirement

        expected_dr_strings = get_dr_comparison_list expected_dr

        diff = expected_dr_strings - actual_dr_strings

        # still output queries even if different from expected.
        queries = get_data_requirements_queries(actual_dr, true)
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
      optional
      include DataRequirementsHelpers
      title 'Data requirements supports optional parameters periodStart and periodEnd'
      id 'data-requirements-02'
      description 'Data requirements returns 200 when periodStart and periodEnd parameters are included'
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01', optional: true
      input :period_end, title: 'Measurement period end', default: '2019-12-31', optional: true
      run do
        # Run our data requirements operation on the test client server
        fhir_operation("Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}",
                       body: PARAMS)
        assert_response_status(200)
        assert_resource_type(:library)
        assert_valid_json(response[:body])
      end
    end

    test do
      include DataRequirementsHelpers
      title 'Check data requirements returns 404 for invalid measure id'
      id 'data-requirements-03'
      description 'Data requirements returns 404 when passed a measure id which is not in the system'

      run do
        # Run our data requirements operation on the test client server
        fhir_operation(
          "Measure/#{INVALID_ID}/$data-requirements",
          body: PARAMS
        )
        assert_dr_failure(expected_status: 404)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
