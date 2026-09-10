# frozen_string_literal: true

require_relative '../patient_everything'
require_relative '../measure_availability'
require_relative '../data_requirements'
require_relative '../fhir_queries'
require_relative '../evaluate_v5'
require_relative '../evaluate_v5_subject_group'
require_relative '../evaluate_v5_subject'
require_relative '../collect_data_v5'
require_relative '../collect_data_v5_subject'
require_relative '../collect_data_v5_subject_group'
require_relative '../submit_data_v5'

module DEQMTestKit
  # Test suite for DEQM Version 5.0.0
  module DEQMV500
    class DEQMTestSuite < Inferno::TestSuite # rubocop:disable Style/Documentation
      id :deqm_v500
      title 'DEQM v5.0.0 Measure Operations Test Suite'
      description 'A set of tests for v5.0.0 DEQM\'s operations and resources'

      input :url

      group do
        id :smart_authorization
        title 'SMART Backend Services Authorization'
        description 'Discover SMART endpoints and obtain a client-credentials access token for DEQM requests.'
        run_as_group

        group from: :smart_discovery_stu2,
              config: {
                inputs: {
                  smart_auth_info: { name: :deqm_smart_auth_info }
                },
                outputs: {
                  smart_auth_info: { name: :deqm_smart_auth_info }
                }
              }

        group from: :backend_services_authorization,
              config: {
                inputs: {
                  smart_auth_info: { name: :deqm_smart_auth_info }
                },
                outputs: {
                  smart_auth_info: { name: :deqm_smart_auth_info }
                }
              }
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
      group do
        id :evaluate
        title '$evaluate Operation'

        input :deqm_smart_auth_info,
              type: :auth_info,
              options: { mode: 'access' }

        fhir_client do
          url :url
          headers origin: url.to_s,
                  referrer: url.to_s,
                  'Content-Type': 'application/fhir+json'
          auth_info :deqm_smart_auth_info
        end

        group from: :evaluate_v5,
              title: '$evaluate',
              config: {
                options: { endpoint_name: 'evaluate' }
              }

        group from: :evaluate_v5_subject,
              title: '$evaluate with subject',
              config: {
                options: { endpoint_name: 'evaluate' }
              }

        group from: :evaluate_v5_subjectGroup,
              title: '$evaluate with subjectGroup',
              config: {
                options: { endpoint_name: 'evaluate' }
              }
      end
      group from: :patient_everything
      group from: :submit_data_v5
      group do
        id :collect_data
        title '$collect-data Operation'

        group from: :collect_data_v5,
              title: '$collect-data'

        group from: :collect_data_v5_subject,
              title: '$collect-data with subject'

        group from: :collect_data_v5_subjectGroup,
              title: '$collect-data with subjectGroup'
      end
    end
  end
end
