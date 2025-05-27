# frozen_string_literal: true

require_relative '../patient_everything'
require_relative '../measure_availability'
require_relative '../data_requirements'
require_relative '../submit_data'
require_relative '../fhir_queries'
require_relative '../bulk_submit_data'
require_relative '../bulk_import'
require_relative '../evaluate_measure'

module DEQMTestKit
  # Test suite for DEQM Version 5.0.0
  module DEQMV500
    class DEQMTestSuite < Inferno::TestSuite # rubocop:disable Style/Documentation
      id :deqm_v500
      title 'DEQM v5.0.0 Measure Operations Test Suite'
      description 'A set of tests for v5.0.0 DEQM\'s operations and resources'

      input :url

      fhir_client do
        url :url
      end

      group do
        id :capability_statement
        title 'Capability Statement'
        description 'Verify that the server has a CapabilityStatement'

        test do
          id :capability_statement_read
          title 'Read CapabilityStatement'
          description 'Read CapabilityStatement from /metadata endpoint'

          run do
            fhir_get_capability_statement

            assert_response_status(200)
            assert_resource_type(:capability_statement)
          end
        end
      end

      group from: :measure_availability
      group from: :data_requirements
      group from: :fhir_queries
      group from: :submit_data
      group from: :evaluate_measure,
            title: '$evaluate Operation',
            config: {
              options: { endpoint_name: 'evaluate' }
            }
      group from: :bulk_submit_data
      group from: :bulk_import
      group from: :patient_everything
    end
  end
end
