# frozen_string_literal: true

module DEQMTestKit
  # tests for $care-gaps
  class CareGaps < Inferno::TestGroup
    id 'care_gaps'
    title 'Gaps in Care'
    description 'Ensure FHIR server can calculate gaps in care for a measure'

    fhir_client do
      url :url
    end

    INVALID_ID = 'INVALID_ID'
    VALID_PARAMS = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=\
    #{period_end}&subject=#{patient_id}&status=open"

    test do
      title 'Check $care-gaps proper calculation'
      id 'care-gaps-01'
      description 'Server should properly return a gaps report'
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        fhir_operation("/Measure/$care-gaps?#{params}")

        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
      end
    end
    test do
      title 'Check $care-gaps missing required parameter'
      id 'care-gaps-02'
      description 'Server should return a 400 response code'
      input :measure_id, :patient_id
      input :period_end, default: '2019-12-31'

      run do
        invalid_params = "measureId=#{measure_id}&periodEnd=#{period_end}&subject=#{patient_id}&status=open"
        fhir_operation("/Measure/$care-gaps?#{invalid_params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    test do
      title 'Check $care-gaps with invalid optional parameters'
      id 'care-gaps-03'
      description 'Server should return a 404 response code'
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      # A request with invalid practitioner and organization ids
      invalid_optional = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=\
      #{period_end}&status=open&practitioner=INVALID&organization=INVALID"
      run do
        fhir_operation("/Measure/$care-gaps?#{invalid_optional}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
    test do
      title 'Check $care-gaps with invalid subject'
      id 'care-gaps-04'
      description 'Server should return a 404 response code'
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      # Parameters with an invalid patient id for subject
      invalid_subject = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=\
      #{period_end}&status=open&subject=INVALID"
      run do
        fhir_operation("/Measure/$care-gaps?#{invalid_subject}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
end
