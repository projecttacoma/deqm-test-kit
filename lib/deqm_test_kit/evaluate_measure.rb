# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate-measure
  # rubocop:disable Metrics/ClassLength
  class EvaluateMeasure < Inferno::TestGroup
    id 'evaluate_measure'
    title 'Evaluate Measure'
    description 'Ensure FHIR server can calculate a measure'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'

    test do
      title 'Check $evaluate-measure proper calculation for individual report'
      id 'evaluate-measure-01'
      description 'Server should properly return an individual measure report'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(200)
        assert_resource_type(:measure_report)
        assert_valid_json(response[:body])
        assert(resource.type == 'individual')
      end
    end

    # NOTE: this test will fail for deqm-test-server
    test do
      title 'Check $evaluate-measure proper calculation for subject-list report'
      id 'evaluate-measure-02'
      description 'Server should properly return a subject-list measure report'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(200)
        assert_resource_type(:measure_report)
        assert_valid_json(response[:body])
        assert(resource.type == 'subject-list')
      end
    end

    test do
      title 'Check $evaluate-measure proper calculation for population report'
      id 'evaluate-measure-03'
      description 'Server should properly return a population measure report'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(200)
        assert_resource_type(:measure_report)
        assert_valid_json(response[:body])
        assert(resource.type == 'summary')
      end
    end

    test do
      title 'Check $evaluate-measure fails for invalid measure ID'
      id 'evaluate-measure-04'
      description 'Request returns a 404 error when the given measure ID cannot be found'
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"
        fhir_operation("/Measure/#{INVALID_MEASURE_ID}/$evaluate-measure?#{params}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for invalid patient ID'
      id 'evaluate-measure-05'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(404)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for missing required param'
      id 'evaluate-measure-06'
      description 'Request returns a 400 error for missing required param (periodStart)'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :patient_id
      input :period_end, default: '2019-12-31'

      run do
        params = "periodEnd=#{period_end}&subject=#{patient_id}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for missing subject param (individual report type)'
      id 'evaluate-measure-07'
      description 'Request returns 400 for missing subject param when individual report type is specified'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end

    test do
      title 'Check $evaluate-measure fails for invalid reportType'
      id 'evaluate-measure-08'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options
      input :patient_id
      input :period_start, default: '2019-01-01'
      input :period_end, default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}&reportType=INVALID"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")

        assert_response_status(400)
        assert_valid_json(response[:body])
        assert(resource.resourceType == 'OperationOutcome')
        assert(resource.issue[0].severity == 'error')
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
