# frozen_string_literal: true

require_relative '../collect_data_v1'

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

      group from: :collect_data_v1
    end
  end
end
