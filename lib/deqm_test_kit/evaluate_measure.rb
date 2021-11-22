# frozen_string_literal: true

module DEQMTestKit
  # tests for $evaluate-measure
  class EvaluateMeasure < Inferno::TestGroup
    id 'evaluate_measure'
    title 'Evaluate Measure'
    description 'Ensure FHIR server can calculate a measure'

    fhir_client do
      url :url
    end

    INVALID_ID = 'INVALID_ID'

    test do
      title 'Check $evaluate-measure proper calculation'
      id 'evaluate-measure-01'
      description 'Server should properly return a measure report'
      input :measure_id, :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(200)
        assert_resource_type(:measure_report)
        assert_valid_json(response[:body])
      end
    end
  end
end
