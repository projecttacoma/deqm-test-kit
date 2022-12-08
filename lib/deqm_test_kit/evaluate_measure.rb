# frozen_string_literal: true

require 'json'

module DEQMTestKit
  # tests for $evaluate-measure
  # rubocop:disable Metrics/ClassLength
  class EvaluateMeasure < Inferno::TestGroup
    # module for shared code for $evaluate-measure assertions and requests
    module MeasureEvaluationHelpers
      def measure_evaluation_assert_success(_report_type, resource_type, params, expected_status: 200)
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")
        assert_success(resource_type, expected_status)
      end

      def measure_evaluation_assert_failure(params, measure_id, expected_status: 400)
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")
        assert_error(expected_status)
      end
    end
    id 'evaluate_measure'
    title 'Evaluate Measure'
    description 'Ensure FHIR server can calculate a measure'

    fhir_client do
      url :url
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    measure_id_args = { type: 'radio', optional: false, default: 'measure-EXM130-7.3.000', options: measure_options }

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
    INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure proper calculation for individual report with required query parameters'
      id 'evaluate-measure-01'
      description %(Server should properly return an individual measure report when provided a
        Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_success('individual', :measure_report, params)
      end
    end

    # NOTE: this test will fail for deqm-test-server
    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure proper calculation for subject-list report with required query parameters'
      id 'evaluate-measure-02'
      description %(Server should properly return subject-list measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=subject-list"
        measure_evaluation_assert_success('subject-list', :measure_report, params)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure proper calculation for population report with required query parameters'
      id 'evaluate-measure-03'
      description %(Server should properly return population measure report when provided a
      Patient ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population"
        fhir_operation("/Measure/#{measure_id}/$evaluate-measure?#{params}")
        measure_evaluation_assert_success('summary', :measure_report, params)
      end
    end
    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure proper calculation for population report with Group subject'
      id 'evaluate-measure-04'
      description %(Server should properly return population measure report when provided a
      Group ID and required query parameters \(period start, period end\).)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'
      input :group_id, title: 'Group ID'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&reportType=population&subject=Group/#{group_id}"
        measure_evaluation_assert_success('summary', :measure_report, params)
      end
    end
    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure fails for invalid measure ID'
      id 'evaluate-measure-05'
      description 'Request returns a 404 error when the given measure ID cannot be found.'
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, INVALID_MEASURE_ID, expected_status: 404)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure fails for invalid patient ID'
      id 'evaluate-measure-06'
      description 'Request returns a 404 error when the given patient ID cannot be found'
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
        measure_evaluation_assert_failure(params, measure_id, expected_status: 404)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure fails for missing required query parameter'
      id 'evaluate-measure-07'
      description %(Server should not perform calculation and return a 400 response code
    when one of the required query parameters is omitted from the request. In this test,
      the measurement period start is omitted from the request.)
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodEnd=#{period_end}&subject=Patient/#{patient_id}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure fails for missing subject query parameter (individual report type)'
      id 'evaluate-measure-08'
      description %(Server should not perform calculation and return a 400 response code
    when the individual report type is specified but no subject has been specified in the
      query parameters.)
      input :measure_id, **measure_id_args
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end

    test do
      include MeasureEvaluationHelpers
      title 'Check $evaluate-measure fails for invalid reportType'
      id 'evaluate-measure-09'
      description 'Request returns 400 for invalid report type (not individual, population, or subject-list)'
      input :measure_id, **measure_id_args
      input :patient_id, title: 'Patient ID'
      input :period_start, title: 'Measurement period start', default: '2019-01-01'
      input :period_end, title: 'Measurement period end', default: '2019-12-31'

      run do
        params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" \
                 "&reportType=#{INVALID_REPORT_TYPE}"
        measure_evaluation_assert_failure(params, measure_id)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
