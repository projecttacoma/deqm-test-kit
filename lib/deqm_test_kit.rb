# frozen_string_literal: true

require_relative 'deqm_test_kit/patient_group'
require_relative 'deqm_test_kit/measure_availability'
require_relative 'deqm_test_kit/data_requirements'
require_relative 'deqm_test_kit/submit_data'
require_relative 'deqm_test_kit/patient_everything'

module DEQMTestKit
  class Suite < Inferno::TestSuite
    id :deqm_test_suite
    title 'DEQM Measure Operations Test Suite'
    description 'A set of tests for DEQM\'s operations and resources'

    # This input will be available to all tests in this suite
    input :url

    # All FHIR requests in this suite will use this FHIR client
    fhir_client do
      url :url
    end

    # Tests and TestGroups can be defined inline
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

    # Tests and TestGroups can be written in separate files and then included
    # using their id
    # group from: :patient_group
    group from: :measure_availability
    group from: :data_requirements
    group from: :submit_data
    group from: :patient_everything
  end
end
