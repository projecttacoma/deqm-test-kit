# frozen_string_literal: true

module Inferno
  module DSL
    # An extension on the existing assertions module to avoid repeptition of block assertions
    module Assertions
      def assert_success(resource_type, expected_status)
        assert_response_status(expected_status)
        assert_resource_type(resource_type)
        assert_valid_json(response[:body])
      end

      def assert_error(expected_status)
        assert_response_status(expected_status)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
end
