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

    test do
      title 'Check $care-gaps proper calculation'
      id 'care-gaps-01'
      description 'Server should properly return a gaps report'
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"
        fhir_operation("/Measure/$care-gaps?#{params}&status=open")

        assert_response_status(200)
        assert_resource_type(:bundle)
        assert_valid_json(response[:body])
      end
    end
  end
end
