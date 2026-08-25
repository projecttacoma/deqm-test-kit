# frozen_string_literal: true

require_relative '../evaluate_v1'
require_relative '../evaluate_v1_subject'
require_relative '../evaluate_v1_subject_group'
require_relative '../collect_data_v1'
require_relative '../collect_data_v1_subject'
require_relative '../collect_data_v1_subject_group'
require_relative '../collect_data_endpoint_v1'

module DEQMTestKit
  # Test suite for DEQM Universal Realm Version 1.0.0
  module DEQMV100
    class DEQMTestKit < Inferno::TestSuite # rubocop:disable Style/Documentation
      id :deqm_v100
      title 'DEQM Universal Realm v1.0.0 Measure Operations Test Suite'
      description 'A set of tests for v1.0.0 DEQM Universal Realm\'s operations and resources'

      input :url

      fhir_client do
        url :url
        headers origin: url.to_s,
                referrer: url.to_s,
                'Content-Type': 'application/fhir+json'
      end

      group do
        id :capability_statement
        title 'Capability Statement'
        description 'Verify that the server has a Capability Statement'

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

      group do
        id :evaluate
        title '$evaluate Operation'

        group from: :evaluate_v1,
              title: '$evaluate'

        group from: :evaluate_v1_subject,
              title: '$evaluate with subject'

        group from: :evaluate_v1_subjectGroup,
              title: '$evaluate with subjectGroup'
      end
      group do
        id :collect_data
        title '$collect-data Operation'

        group from: :collect_data_v1,
              title: '$collect-data'

        group from: :collect_data_v1_subject,
              title: '$collect-data with subject'

        group from: :collect_data_v1_subjectGroup,
              title: '$collect-data with subjectGroup'

        group from: :collect_data_endpoint_v1
      end
    end
  end
end
